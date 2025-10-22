-- 🚀 RooCode Patch: Migration v5 + Trip Lifecycle Sync
-- This migration ensures schema and Flutter code are aligned for Week 4 Trip Lifecycle

-- ✅ Fix trips status enum
ALTER TABLE trips 
DROP CONSTRAINT IF EXISTS trips_status_check,
ADD CONSTRAINT trips_status_check CHECK (
  status IN ('scheduled', 'accepted', 'driver_arrived', 'in_progress', 'completed', 'cancelled')
);

-- ✅ Ensure notifications has data JSONB
ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS data JSONB;

-- ✅ Enable RLS
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ✅ Trip policies
CREATE POLICY IF NOT EXISTS rider_view_trips ON trips
  FOR SELECT USING (auth.uid() = rider_id);

CREATE POLICY IF NOT EXISTS driver_view_trips ON trips
  FOR SELECT USING (auth.uid() = driver_id);

CREATE POLICY IF NOT EXISTS driver_update_trip_status ON trips
  FOR UPDATE USING (auth.uid() = driver_id);

-- ✅ Notifications policies
CREATE POLICY IF NOT EXISTS view_own_notifications ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- ✅ Update any existing trips with old status values
UPDATE trips 
SET status = CASE 
  WHEN status = 'pending' THEN 'scheduled'
  WHEN status = 'on_my_way' THEN 'driver_arrived'
  ELSE status
END
WHERE status IN ('pending', 'on_my_way');

-- ✅ Verify the constraint was applied
SELECT conname, consrc 
FROM pg_constraint 
WHERE conname = 'trips_status_check';

-- ✅ Verify notifications table has data column
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notifications' AND column_name = 'data';

-- ✅ Verify RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('trips', 'notifications');