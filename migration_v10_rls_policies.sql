-- Migration: v10 Row Level Security (RLS) Policies
-- Description: Update RLS policies for v10 security requirements

-- Enable RLS on all tables
ALTER TABLE telemetry_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_approval_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE realtime_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS telemetry_insert_policy ON telemetry_logs;
DROP POLICY IF EXISTS telemetry_select_policy ON telemetry_logs;
DROP POLICY IF EXISTS profiles_select_policy ON profiles;
DROP POLICY IF EXISTS profiles_insert_policy ON profiles;
DROP POLICY IF EXISTS profiles_update_policy ON profiles;
DROP POLICY IF EXISTS drivers_select_policy ON drivers;
DROP POLICY IF EXISTS drivers_insert_policy ON drivers;
DROP POLICY IF EXISTS drivers_update_policy ON drivers;
DROP POLICY IF EXISTS trips_select_policy ON trips;
DROP POLICY IF EXISTS trips_insert_policy ON trips;
DROP POLICY IF EXISTS trips_update_policy ON trips;
DROP POLICY IF EXISTS wallet_select_policy ON wallet_transactions;
DROP POLICY IF EXISTS wallet_insert_policy ON wallet_transactions;
DROP POLICY IF EXISTS wallet_update_policy ON wallet_transactions;
DROP POLICY IF EXISTS push_select_policy ON push_notifications;
DROP POLICY IF EXISTS push_insert_policy ON push_notifications;
DROP POLICY IF EXISTS push_update_policy ON push_notifications;
DROP POLICY IF EXISTS session_select_policy ON session_logs;
DROP POLICY IF EXISTS session_insert_policy ON session_logs;
DROP POLICY IF EXISTS session_update_policy ON session_logs;
DROP POLICY IF EXISTS approval_select_policy ON driver_approval_history;
DROP POLICY IF EXISTS approval_insert_policy ON driver_approval_history;
DROP POLICY IF EXISTS approval_update_policy ON driver_approval_history;
DROP POLICY IF EXISTS fcm_select_policy ON fcm_tokens;
DROP POLICY IF EXISTS fcm_insert_policy ON fcm_tokens;
DROP POLICY IF EXISTS fcm_update_policy ON fcm_tokens;
DROP POLICY IF EXISTS realtime_select_policy ON realtime_subscriptions;
DROP POLICY IF EXISTS realtime_insert_policy ON realtime_subscriptions;
DROP POLICY IF EXISTS realtime_update_policy ON realtime_subscriptions;
DROP POLICY IF EXISTS performance_select_policy ON performance_metrics;
DROP POLICY IF EXISTS performance_insert_policy ON performance_metrics;
DROP POLICY IF EXISTS performance_update_policy ON performance_metrics;

-- Telemetry Logs Policies
-- Allow service role to insert telemetry (for batch processing)
CREATE POLICY telemetry_insert_policy ON telemetry_logs
FOR INSERT TO service_role
WITH CHECK (true);

-- Allow authenticated users to read their own telemetry
CREATE POLICY telemetry_select_policy ON telemetry_logs
FOR SELECT TO authenticated
USING (auth.uid()::text = (meta->>'user_id') OR meta->>'user_id' IS NULL);

-- Profiles Policies
-- Users can read their own profile
CREATE POLICY profiles_select_policy ON profiles
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY profiles_insert_policy ON profiles
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY profiles_update_policy ON profiles
FOR UPDATE TO authenticated
USING (auth.uid() = user_id);

-- Drivers Policies
-- Drivers can read their own driver record
CREATE POLICY drivers_select_policy ON drivers
FOR SELECT TO authenticated
USING (auth.uid() = profile_id);

-- Drivers can insert their own driver record
CREATE POLICY drivers_insert_policy ON drivers
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = profile_id);

-- Drivers can update their own driver record (except approval_status)
CREATE POLICY drivers_update_policy ON drivers
FOR UPDATE TO authenticated
USING (auth.uid() = profile_id)
WITH CHECK (
  auth.uid() = profile_id AND 
  (OLD.approval_status = NEW.approval_status OR 
   auth.jwt() ->> 'role' = 'service_role')
);

-- Admin role can update approval status
CREATE POLICY drivers_admin_update_policy ON drivers
FOR UPDATE TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- Trips Policies
-- Drivers can read trips assigned to them
CREATE POLICY trips_driver_select_policy ON trips
FOR SELECT TO authenticated
USING (
  driver_id = auth.uid() OR 
  status IN ('requested', 'available')
);

-- Customers can read their own trips
CREATE POLICY trips_customer_select_policy ON trips
FOR SELECT TO authenticated
USING (customer_id = auth.uid());

-- Drivers can update trips they're assigned to
CREATE POLICY trips_driver_update_policy ON trips
FOR UPDATE TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- Customers can insert their own trips
CREATE POLICY trips_customer_insert_policy ON trips
FOR INSERT TO authenticated
WITH CHECK (customer_id = auth.uid());

-- Wallet Transactions Policies
-- Users can read their own wallet transactions
CREATE POLICY wallet_select_policy ON wallet_transactions
FOR SELECT TO authenticated
USING (driver_id = auth.uid());

-- Service role can insert wallet transactions (for system operations)
CREATE POLICY wallet_insert_policy ON wallet_transactions
FOR INSERT TO service_role
WITH CHECK (true);

-- Push Notifications Policies
-- Users can read their own push notifications
CREATE POLICY push_select_policy ON push_notifications
FOR SELECT TO authenticated
USING (driver_id = auth.uid());

-- Service role can insert push notifications
CREATE POLICY push_insert_policy ON push_notifications
FOR INSERT TO service_role
WITH CHECK (true);

-- Users can update their own push notification status
CREATE POLICY push_update_policy ON push_notifications
FOR UPDATE TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- Session Logs Policies
-- Users can read their own session logs
CREATE POLICY session_select_policy ON session_logs
FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Service role can insert session logs
CREATE POLICY session_insert_policy ON session_logs
FOR INSERT TO service_role
WITH CHECK (true);

-- Driver Approval History Policies
-- Drivers can read their own approval history
CREATE POLICY approval_select_policy ON driver_approval_history
FOR SELECT TO authenticated
USING (driver_id = auth.uid());

-- Admin role can read all approval history
CREATE POLICY approval_admin_select_policy ON driver_approval_history
FOR SELECT TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- Admin role can insert approval history
CREATE POLICY approval_insert_policy ON driver_approval_history
FOR INSERT TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- FCM Tokens Policies
-- Users can read their own FCM tokens
CREATE POLICY fcm_select_policy ON fcm_tokens
FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own FCM tokens
CREATE POLICY fcm_insert_policy ON fcm_tokens
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own FCM tokens
CREATE POLICY fcm_update_policy ON fcm_tokens
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Realtime Subscriptions Policies
-- Users can read their own subscriptions
CREATE POLICY realtime_select_policy ON realtime_subscriptions
FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Users can insert their own subscriptions
CREATE POLICY realtime_insert_policy ON realtime_subscriptions
FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can update their own subscriptions
CREATE POLICY realtime_update_policy ON realtime_subscriptions
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Performance Metrics Policies
-- Service role can insert performance metrics
CREATE POLICY performance_insert_policy ON performance_metrics
FOR INSERT TO service_role
WITH CHECK (true);

-- Admin role can read performance metrics
CREATE POLICY performance_select_policy ON performance_metrics
FOR SELECT TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO service_role;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Verify RLS policies are in place
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;