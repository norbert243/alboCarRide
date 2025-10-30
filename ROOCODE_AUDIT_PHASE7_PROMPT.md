# Phase 7 RooCode Audit Prompt

## Objective
Verify that live trip navigation and tracking are fully integrated and operational.

## Audit Checks
1. Confirm presence of `update_driver_location` and `update_trip_status` RPCs in Supabase schema.  
2. Verify `driver_live_trip_screen.dart` subscribes to GPS stream and updates database every ≤ 2 s.  
3. Confirm trip status updates correctly propagate to `driver_state_events`.  
4. Ensure Google Maps renders without crash on Android emulator.  
5. Validate `driver_arrived`, `in_progress`, and `completed` transitions are visible in UI.  
6. Confirm no memory leaks or redundant rebuilds occur on navigation.
7. Verify location tracking accuracy and database update frequency.
8. Check trip marker and polyline rendering on map.
9. Validate real-time location updates in `driver_locations` table.
10. Confirm trip status lifecycle transitions work correctly.

## Expected JSON Audit Output
```json
{
  "rpc_functions_verified": 2,
  "driver_location_stream_active": true,
  "trip_status_updates": true,
  "map_render_ok": true,
  "schema_integrity_ok": true,
  "location_tracking_accuracy": "high",
  "database_update_frequency": "≤2s",
  "marker_rendering": true,
  "polyline_rendering": true,
  "status_transitions_verified": true,
  "memory_leaks_detected": false,
  "ready_for_phase8": true
}
```

## Implementation Verification Steps

### 1. Database Schema Verification
```sql
-- Check RPC functions exist
SELECT proname FROM pg_proc WHERE proname IN ('update_driver_location', 'update_trip_status');

-- Verify driver_locations table structure
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'driver_locations';

-- Check recent driver_state_events
SELECT event_type, COUNT(*) FROM driver_state_events 
WHERE event_type IN ('driver_location_update', 'trip_status_update')
GROUP BY event_type;
```

### 2. Flutter Implementation Verification
```dart
// Verify location stream subscription
final locationStream = Geolocator.getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
  ),
);

// Check database update frequency
// Should update every 2 seconds maximum
// Should handle location permission flows
// Should properly dispose of resources
```

### 3. Google Maps Integration
- Verify `google_maps_flutter` package is properly configured
- Check API keys and permissions for Android
- Validate marker and polyline rendering
- Confirm camera follows driver location

### 4. Trip Status Lifecycle
- Verify status transitions: `driver_arrived` → `in_progress` → `completed`
- Check database updates for each status change
- Validate real-time event propagation

### 5. Performance & Memory
- Check for memory leaks in location subscription
- Verify proper disposal of map controller
- Monitor CPU usage during live tracking
- Check battery impact of continuous location updates

## Test Scenarios

### Scenario 1: Location Tracking
1. Start DriverLiveTripScreen
2. Move device to simulate driving
3. Verify location updates in database every 2 seconds
4. Check map follows driver position

### Scenario 2: Status Transitions  
1. Tap "Arrived" button
2. Verify status changes to `driver_arrived`
3. Tap "Start Trip" button
4. Verify status changes to `in_progress`
5. Tap "Complete" button
6. Verify status changes to `completed`

### Scenario 3: Map Features
1. Verify pickup and destination markers render
2. Check route polyline displays
3. Confirm map controls work properly
4. Test zoom and pan functionality

## Success Criteria
- All RPC functions execute without errors
- Location updates occur within 2-second intervals
- Status transitions update database and UI simultaneously
- Map renders without crashes or visual artifacts
- No memory leaks detected during extended use
- Battery usage remains reasonable for navigation app