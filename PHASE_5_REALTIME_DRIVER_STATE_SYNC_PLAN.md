# Phase 5: Realtime Driver State Sync Implementation Plan

## 🎯 Objective
Implement lightweight real-time synchronization for driver state (online/offline, location, active trip status) to provide live updates across devices without manual refresh.

## 📋 Current State Assessment

### ✅ Phase 4 Completed:
- Driver Dashboard v2 widget created and integrated
- RPC function `get_driver_dashboard()` implemented
- Telemetry schema with `driver_id` column added
- Field mapping verified and working
- 10-second timer-based refresh implemented

### 🔄 Phase 5 Enhancement:
Replace timer-based polling with real-time subscriptions for instant updates.

## 🏗️ Architecture Components

### 1. Supabase Realtime Channels
```sql
-- Enable realtime for relevant tables
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.telemetry_logs REPLICA IDENTITY FULL;
ALTER TABLE public.driver_wallets REPLICA IDENTITY FULL;
ALTER TABLE public.trips REPLICA IDENTITY FULL;
```

### 2. Flutter Stream Subscriptions
```dart
// Replace Timer with StreamSubscription
StreamSubscription? _dashboardSubscription;

// Subscribe to multiple realtime channels
_subscribeToRealtimeUpdates() {
  _dashboardSubscription = Supabase.instance.client
    .channel('driver-dashboard')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'drivers',
      callback: (payload) => _handleDriverUpdate(payload),
    )
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'driver_wallets',
      callback: (payload) => _handleWalletUpdate(payload),
    )
    .subscribe();
}
```

### 3. SQL Triggers for State Changes
```sql
-- Trigger to emit telemetry on driver status changes
CREATE OR REPLACE FUNCTION public.emit_driver_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_online IS DISTINCT FROM NEW.is_online THEN
    INSERT INTO public.telemetry_logs (driver_id, type, message, meta)
    VALUES (
      NEW.id,
      'status_change',
      format('Driver %s status: %s -> %s', NEW.id, OLD.is_online, NEW.is_online),
      jsonb_build_object('old_status', OLD.is_online, 'new_status', NEW.is_online)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER driver_status_change_trigger
  AFTER UPDATE ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.emit_driver_status_change();
```

## 🎨 User Experience Improvements

### Current (Phase 4):
- Manual pull-to-refresh
- 10-second timer updates
- Static status display

### Enhanced (Phase 5):
- Instant status updates (online/offline/trip)
- Live location tracking
- Real-time earnings updates
- Push notifications for state changes

## 🔧 Implementation Steps

### Step 1: Database Preparation
1. Enable realtime for key tables
2. Create status change triggers
3. Add realtime policies

### Step 2: Flutter Integration
1. Replace Timer with StreamSubscription
2. Implement realtime channel management
3. Add connection state handling

### Step 3: UI Enhancements
1. Add real-time status indicators
2. Implement connection status display
3. Add offline/online state visualization

### Step 4: Testing & Validation
1. Test realtime updates
2. Validate connection resilience
3. Performance benchmarking

## 📊 Expected Benefits

| Metric | Phase 4 (Timer) | Phase 5 (Realtime) |
|--------|-----------------|-------------------|
| Update Latency | 10 seconds | < 1 second |
| Network Calls | High (polling) | Low (subscription) |
| Battery Impact | Medium | Low |
| User Experience | Good | Excellent |

## 🛡️ Safety Considerations

### Non-Breaking Changes:
- Maintain backward compatibility
- Keep existing timer as fallback
- No modifications to working auth/trip logic
- Preserve all existing RPC functions

### Error Handling:
- Automatic reconnection on network issues
- Graceful degradation to polling mode
- Connection status indicators

## 🎯 Success Criteria

### Technical:
- ✅ Real-time updates within 1 second
- ✅ Stable connection management
- ✅ Proper error handling and recovery
- ✅ No impact on existing functionality

### User Experience:
- ✅ Instant status updates
- ✅ Smooth transition between states
- ✅ Clear connection status
- ✅ Improved battery efficiency

## 📋 Next Steps After Phase 5

1. **Phase 6**: Advanced analytics and predictive features
2. **Phase 7**: Multi-driver coordination and fleet management
3. **Phase 8**: Advanced notification system with smart routing

## 🚀 Immediate Next Action

Run the Phase 4 audit using the RooCode prompt to verify current implementation before proceeding to Phase 5 realtime enhancements.