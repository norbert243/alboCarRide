# Heat Map Integration Guide for AlboCarRide
## Demand/Supply Visualization for Ride-Hailing Platform

---

## Executive Summary

Heat maps provide visual representation of:
- **Demand hotspots:** Where customers are requesting rides
- **Supply distribution:** Where drivers are currently located
- **Surge pricing zones:** High-demand areas needing dynamic pricing

**Recommended Solution:** Custom Flutter implementation using `google_maps_flutter` + overlay rendering

---

## Why Heat Maps Matter for Ride-Hailing

### Business Benefits
1. **Driver positioning:** Help drivers move to high-demand areas
2. **Surge pricing:** Justify dynamic pricing with visual proof
3. **Supply optimization:** Balance driver distribution across city
4. **Analytics:** Understand demand patterns over time

### User Benefits
1. **Drivers:** See where to position for more trips
2. **Customers:** Understand why surge pricing is active
3. **Platform:** Data-driven decision making

---

## Research Findings

### Critical Update (2025)
⚠️ **Google Maps JavaScript API Heatmap Layer was deprecated in May 2025**
- Will be unavailable in May 2026
- **Impact:** Web applications only (not mobile)
- **Mobile apps:** Unaffected - can still use heatmap overlays

### Available Solutions

| Solution | Platform | Pros | Cons | Status |
|----------|----------|------|------|--------|
| **Google Maps Heatmap Layer** | Web | Native integration | Deprecated May 2025 | ⚠️ Avoid for web |
| **google_maps_flutter_heatmap** | Mobile (iOS/Android) | Works with Google Maps | Limited maintenance | ✅ Use for mobile |
| **flutter_map_heatmap** | Mobile (any map) | Independent of Google | Less features | ✅ Alternative |
| **Custom Overlay Rendering** | All | Full control | More development | ✅✅ Recommended |
| **deck.gl** | Web | Powerful | Complex setup | Future consideration |

---

## Recommended Implementation: Custom Overlay + Flutter

### Architecture

```
┌─────────────────────────────────────┐
│     Google Maps (Base Layer)        │
└─────────────────────────────────────┘
           ↑
           │
┌─────────────────────────────────────┐
│   Heat Map Overlay (Demand/Supply)  │
│   - Customer request density        │
│   - Driver location density         │
│   - Color-coded intensity           │
└─────────────────────────────────────┘
           ↑
           │
┌─────────────────────────────────────┐
│   Real-time Data (Supabase)        │
│   - Active ride requests            │
│   - Online driver locations         │
│   - Historical demand data          │
└─────────────────────────────────────┘
```

---

## Implementation Guide

### Phase 1: Database Schema for Heat Map Data

```sql
-- Demand/Supply tracking table
CREATE TABLE IF NOT EXISTS public.demand_supply_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Location
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    location_grid_id TEXT, -- Grid cell identifier (e.g., "9.0-18.5")

    -- Metrics
    active_requests INTEGER DEFAULT 0,
    available_drivers INTEGER DEFAULT 0,
    demand_supply_ratio NUMERIC(5, 2), -- requests / drivers

    -- Time-based tracking
    hour_of_day INTEGER CHECK (hour_of_day >= 0 AND hour_of_day < 24),
    day_of_week INTEGER CHECK (day_of_week >= 0 AND day_of_week < 7),

    -- Surge pricing
    surge_multiplier NUMERIC(3, 2) DEFAULT 1.0,

    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial index for fast geo queries
CREATE INDEX idx_demand_supply_location ON public.demand_supply_metrics
    USING gist (ll_to_earth(latitude, longitude));

-- Time-based index
CREATE INDEX idx_demand_supply_time ON public.demand_supply_metrics(timestamp DESC);

-- Function to calculate grid cell ID from coordinates
CREATE OR REPLACE FUNCTION get_grid_cell_id(lat NUMERIC, lng NUMERIC, grid_size NUMERIC DEFAULT 0.05)
RETURNS TEXT AS $$
BEGIN
    RETURN CONCAT(
        FLOOR(lat / grid_size) * grid_size,
        '-',
        FLOOR(lng / grid_size) * grid_size
    );
END;
$$ LANGUAGE plpgsql;

-- Function to aggregate demand/supply in real-time
CREATE OR REPLACE FUNCTION calculate_demand_supply_heatmap()
RETURNS TABLE (
    grid_id TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    request_count BIGINT,
    driver_count BIGINT,
    intensity NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH grid_requests AS (
        SELECT
            get_grid_cell_id(pickup_latitude, pickup_longitude) AS grid_id,
            AVG(pickup_latitude) AS lat,
            AVG(pickup_longitude) AS lng,
            COUNT(*) AS requests
        FROM ride_requests
        WHERE status = 'pending'
            AND created_at > NOW() - INTERVAL '30 minutes'
        GROUP BY get_grid_cell_id(pickup_latitude, pickup_longitude)
    ),
    grid_drivers AS (
        SELECT
            get_grid_cell_id(current_latitude, current_longitude) AS grid_id,
            COUNT(*) AS drivers
        FROM profiles
        WHERE role = 'driver'
            AND is_online = TRUE
            AND current_latitude IS NOT NULL
            AND last_location_update > NOW() - INTERVAL '5 minutes'
        GROUP BY get_grid_cell_id(current_latitude, current_longitude)
    )
    SELECT
        COALESCE(r.grid_id, d.grid_id) AS grid_id,
        COALESCE(r.lat, 0) AS latitude,
        COALESCE(r.lng, 0) AS longitude,
        COALESCE(r.requests, 0) AS request_count,
        COALESCE(d.drivers, 0) AS driver_count,
        CASE
            WHEN COALESCE(d.drivers, 0) = 0 THEN COALESCE(r.requests, 0)::NUMERIC * 2
            ELSE COALESCE(r.requests, 0)::NUMERIC / COALESCE(d.drivers, 1)::NUMERIC
        END AS intensity
    FROM grid_requests r
    FULL OUTER JOIN grid_drivers d ON r.grid_id = d.grid_id;
END;
$$ LANGUAGE plpgsql;
```

### Phase 2: Flutter Service for Heat Map Data

```dart
// lib/services/heatmap_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatMapPoint {
  final LatLng location;
  final double intensity; // 0.0 - 1.0
  final int requestCount;
  final int driverCount;

  HeatMapPoint({
    required this.location,
    required this.intensity,
    required this.requestCount,
    required this.driverCount,
  });

  Color get color {
    // Gradient from green (low demand) to red (high demand)
    if (intensity < 0.5) {
      return Color.lerp(Colors.green, Colors.yellow, intensity * 2)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (intensity - 0.5) * 2)!;
    }
  }
}

class HeatMapService {
  final SupabaseClient _supabase;

  HeatMapService(this._supabase);

  /// Get real-time heat map data
  Future<List<HeatMapPoint>> getHeatMapData() async {
    try {
      final response = await _supabase.rpc('calculate_demand_supply_heatmap');

      final List<HeatMapPoint> points = [];
      double maxIntensity = 0;

      // Find max intensity for normalization
      for (final row in response) {
        final intensity = (row['intensity'] as num).toDouble();
        if (intensity > maxIntensity) maxIntensity = intensity;
      }

      // Create heat map points
      for (final row in response) {
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        final intensity = (row['intensity'] as num).toDouble();
        final requests = row['request_count'] as int;
        final drivers = row['driver_count'] as int;

        // Skip points with no data
        if (lat == 0 && lng == 0) continue;

        points.add(
          HeatMapPoint(
            location: LatLng(lat, lng),
            intensity: maxIntensity > 0 ? intensity / maxIntensity : 0,
            requestCount: requests,
            driverCount: drivers,
          ),
        );
      }

      return points;
    } catch (e) {
      print('Error fetching heat map data: $e');
      return [];
    }
  }

  /// Stream real-time updates
  Stream<List<HeatMapPoint>> watchHeatMapData() {
    return Stream.periodic(
      const Duration(seconds: 30),
      (_) => getHeatMapData(),
    ).asyncMap((future) => future);
  }

  /// Get historical demand patterns
  Future<Map<int, double>> getHourlyDemandPattern() async {
    // Returns average demand by hour of day
    final response = await _supabase
        .from('demand_supply_metrics')
        .select('hour_of_day, demand_supply_ratio')
        .gte('timestamp', DateTime.now().subtract(Duration(days: 7)));

    final Map<int, List<double>> hourlyData = {};

    for (final row in response) {
      final hour = row['hour_of_day'] as int;
      final ratio = (row['demand_supply_ratio'] as num?)?.toDouble() ?? 0;

      hourlyData.putIfAbsent(hour, () => []).add(ratio);
    }

    // Calculate averages
    return hourlyData.map((hour, ratios) {
      final avg = ratios.reduce((a, b) => a + b) / ratios.length;
      return MapEntry(hour, avg);
    });
  }
}
```

### Phase 3: Heat Map Widget

```dart
// lib/widgets/heat_map_overlay.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatMapOverlay extends StatelessWidget {
  final List<HeatMapPoint> heatMapPoints;
  final GoogleMapController mapController;

  const HeatMapOverlay({
    super.key,
    required this.heatMapPoints,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: heatMapPoints.map((point) {
        return Positioned(
          // Convert LatLng to screen coordinates
          child: _buildHeatCircle(point),
        );
      }).toList(),
    );
  }

  Widget _buildHeatCircle(HeatMapPoint point) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            point.color.withOpacity(point.intensity * 0.6),
            point.color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

// Alternative: Use Circles on Google Map
Set<Circle> buildHeatMapCircles(List<HeatMapPoint> points) {
  return points.map((point) {
    return Circle(
      circleId: CircleId('heat_${point.location.latitude}_${point.location.longitude}'),
      center: point.location,
      radius: 500, // meters
      fillColor: point.color.withOpacity(0.3),
      strokeColor: point.color,
      strokeWidth: 2,
    );
  }).toSet();
}
```

### Phase 4: Integration in Driver/Admin App

```dart
// lib/screens/driver/heat_map_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatMapPage extends StatefulWidget {
  const HeatMapPage({super.key});

  @override
  State<HeatMapPage> createState() => _HeatMapPageState();
}

class _HeatMapPageState extends State<HeatMapPage> {
  final HeatMapService _heatMapService = HeatMapService(
    Supabase.instance.client,
  );

  GoogleMapController? _mapController;
  List<HeatMapPoint> _heatMapPoints = [];
  bool _showDemand = true; // Toggle between demand/supply view

  @override
  void initState() {
    super.initState();
    _loadHeatMapData();

    // Auto-refresh every 30 seconds
    Timer.periodic(Duration(seconds: 30), (_) {
      _loadHeatMapData();
    });
  }

  Future<void> _loadHeatMapData() async {
    final points = await _heatMapService.getHeatMapData();
    setState(() {
      _heatMapPoints = points;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Heat Map'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadHeatMapData,
          ),
          Switch(
            value: _showDemand,
            onChanged: (value) {
              setState(() => _showDemand = value);
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(-4.3276, 15.3136), // Kinshasa
          zoom: 12,
        ),
        circles: buildHeatMapCircles(_heatMapPoints),
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
      bottomSheet: _buildLegend(),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heat Map Legend', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.green, 'Low Demand'),
              SizedBox(width: 16),
              _buildLegendItem(Colors.yellow, 'Medium Demand'),
              SizedBox(width: 16),
              _buildLegendItem(Colors.red, 'High Demand'),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Last updated: ${DateTime.now().toString().substring(11, 16)}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
```

---

## Advanced Features

### 1. Surge Pricing Integration

```dart
double calculateSurgeMultiplier(HeatMapPoint point) {
  // High demand (red zones) = surge pricing
  if (point.intensity > 0.8) {
    return 2.0; // 2x price
  } else if (point.intensity > 0.6) {
    return 1.5; // 1.5x price
  } else {
    return 1.0; // Normal price
  }
}
```

### 2. Driver Notifications

```dart
// Notify drivers when they enter low-supply zones
void notifyDriverAboutHighDemandArea(HeatMapPoint point) {
  if (point.requestCount > 5 && point.driverCount < 2) {
    showNotification(
      title: 'High Demand Area!',
      body: '${point.requestCount} customers waiting nearby. Move here for more trips!',
    );
  }
}
```

### 3. Predictive Analytics

```dart
// Predict demand based on historical patterns
Future<List<HeatMapPoint>> predictDemand({
  required int hour,
  required int dayOfWeek,
}) async {
  // Use historical data to predict future demand
  // Helpful for drivers to position themselves before rush hour
}
```

---

## Performance Optimization

### Data Aggregation
- **Grid Size:** 0.05 degrees (~5km cells) for city-level
- **Update Frequency:** Every 30 seconds (balance freshness vs load)
- **Historical Cleanup:** Delete metrics older than 30 days

### Rendering Optimization
- Limit to 50-100 heat points max
- Use clustering for overlapping points
- Lazy load heat map (only show when zoomed in)

### Caching Strategy
```dart
class HeatMapCache {
  static Map<String, List<HeatMapPoint>> _cache = {};
  static DateTime? _lastUpdate;

  static Future<List<HeatMapPoint>> getHeatMapData({
    required HeatMapService service,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    if (_lastUpdate != null &&
        DateTime.now().difference(_lastUpdate!) < cacheDuration) {
      return _cache['data'] ?? [];
    }

    final data = await service.getHeatMapData();
    _cache['data'] = data;
    _lastUpdate = DateTime.now();

    return data;
  }
}
```

---

## Mobile vs Web Implementation

| Platform | Recommended Approach | Library |
|----------|---------------------|---------|
| **iOS** | Google Maps + Custom Circles | `google_maps_flutter` |
| **Android** | Google Maps + Custom Circles | `google_maps_flutter` |
| **Web** | deck.gl or custom canvas | `flutter_map` + canvas |

---

## Testing Strategy

### Unit Tests
- Test grid cell ID calculation
- Test intensity normalization
- Test color gradient generation

### Integration Tests
- Test database function performance
- Test real-time data streaming
- Test heat map rendering with 100+ points

### Load Tests
- Simulate 1000 concurrent drivers viewing heat map
- Measure database query performance
- Test update frequency impact

---

## Privacy & Security

### Data Anonymization
- Don't show exact customer/driver locations
- Use aggregated grid cells only
- Minimum 3 requests per cell before displaying

### Access Control
- Heat map visible only to:
  - Active drivers (to find demand)
  - Platform admins (for analytics)
- NOT visible to customers (competitive advantage)

---

## Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1:** Database Setup | 1 week | Tables, functions, indexes |
| **Phase 2:** Service Layer | 1 week | HeatMapService, data aggregation |
| **Phase 3:** UI Implementation | 2 weeks | Heat map widget, legend, controls |
| **Phase 4:** Testing & Optimization | 1 week | Performance tuning, bug fixes |
| **Phase 5:** Launch | 1 week | Beta test, full rollout |

**Total:** 6 weeks

---

## Success Metrics

1. **Driver Engagement:** 60%+ of drivers check heat map daily
2. **Positioning Efficiency:** 20% reduction in empty driver time
3. **Surge Acceptance:** 80%+ customers accept surge pricing with visual justification
4. **Performance:** Heat map loads in <2 seconds
5. **Accuracy:** 90%+ correlation between predicted and actual demand

---

## Alternative: Simplified Version (MVP)

If full heat map is too complex, start with:

### Simple Demand Indicator
```dart
// Show demand level by area (text-based)
String getDemandLevel(LatLng location) {
  // Query nearby requests
  final nearbyRequests = await getNearbyRequests(location, radius: 3000);

  if (nearbyRequests > 10) return '🔥 Very High Demand';
  if (nearbyRequests > 5) return '⚡ High Demand';
  if (nearbyRequests > 2) return '✅ Moderate Demand';
  return '😴 Low Demand';
}
```

**Pros:** Much simpler, faster to implement
**Cons:** Less visual, less actionable insights

---

## Final Recommendation

### For AlboCarRide DRC:

1. **Start Simple:** Implement basic demand indicators first
2. **Add Heat Map:** Once you have 50+ active drivers
3. **Use Custom Circles:** Avoid deprecated Google features
4. **Real-time Updates:** 30-second refresh interval
5. **Focus on Drivers:** Heat map primarily for driver positioning

### Priority Level: **Medium** (implement after core features stable)

---

**Status:** Implementation guide ready
**Recommended Start Date:** After driver tier system launch
**Estimated Development Time:** 6 weeks
**Expected Impact:** 15-20% improvement in driver utilization
