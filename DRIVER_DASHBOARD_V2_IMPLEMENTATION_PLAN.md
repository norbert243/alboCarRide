# Driver Dashboard v2 Implementation Plan

## Overview
This document outlines the implementation plan for adding a new Driver Dashboard v2 widget that extends the existing functionality without modifying any working Auth or existing Dashboard v1 code.

## Implementation Requirements

### Core Widget Specifications
- **Widget Name**: `DriverDashboardV2`
- **Location**: `lib/screens/home/driver_dashboard_v2.dart`
- **Features**: 
  - Displays live driver analytics from `get_driver_dashboard()` RPC
  - Updates every 10 seconds
  - Shows key metrics and last telemetry ping
  - Uses real driver ID: `2c1454d6-a53a-40ab-b3d9-2d367a8eab57` for testing

### Widget Code Template
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverDashboardV2 extends StatefulWidget {
  final String driverId;
  const DriverDashboardV2({Key? key, required this.driverId}) : super(key: key);

  @override
  State<DriverDashboardV2> createState() => _DriverDashboardV2State();
}

class _DriverDashboardV2State extends State<DriverDashboardV2> {
  Map<String, dynamic>? dashboardData;
  Timer? refreshTimer;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchDashboard();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    setState(() => loading = true);
    try {
      final response = await Supabase.instance.client
          .rpc('get_driver_dashboard', params: {'p_driver_id': widget.driverId});
      setState(() => dashboardData = response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('⚠️ Dashboard fetch failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = dashboardData;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Dashboard v2')),
      body: loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _metric('Driver Name', d?['driver_name']),
                  _metric('Online', d?['is_online']),
                  _metric('Rating', d?['rating']),
                  _metric('Trips Today', d?['total_trips']),
                  _metric('Earnings Today', 'R ${d?['earnings_today'] ?? 0}'),
                  _metric('Online Time (sec)', d?['online_seconds']),
                  _metric('Last Seen', d?['last_seen']),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
```

## Integration Steps

### 1. Route Registration in main.dart
- Add new route: `/driver-dashboard-v2`
- Ensure no conflicts with existing routes
- Maintain backward compatibility

### 2. Testing Requirements
- Verify RPC function `get_driver_dashboard` integration
- Test with driver ID: `2c1454d6-a53a-40ab-b3d9-2d367a8eab57`
- Validate 10-second refresh interval
- Confirm no impact on existing Auth system
- Ensure Dashboard v1 remains fully functional

### 3. Security Considerations
- RPC function must have proper RLS policies
- Driver ID validation and authentication
- Error handling for failed RPC calls

## Success Criteria
- ✅ Widget displays live driver analytics
- ✅ Automatic refresh every 10 seconds
- ✅ No impact on existing Auth or Dashboard v1
- ✅ Proper error handling and loading states
- ✅ Integration with existing RPC function

## Next Steps
1. Switch to Code mode to implement the widget
2. Create the widget file at specified location
3. Register the route in main.dart
4. Test integration with real driver ID
5. Validate no impact on existing systems

## Risk Mitigation
- **No modifications to existing Auth code** - Widget extends functionality only
- **Dashboard v1 remains untouched** - New widget is completely separate
- **RPC function already exists** - Using established database function
- **Error handling implemented** - Graceful degradation on failures