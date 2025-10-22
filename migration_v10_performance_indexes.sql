-- Migration: v10 Performance Indexes
-- Description: Create optimized indexes for v10 architecture performance

-- Index for telemetry_logs table (batch processing optimization)
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_type_timestamp 
ON telemetry_logs (type, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_logs_timestamp 
ON telemetry_logs (timestamp DESC);

-- Index for profiles table (driver approval system)
CREATE INDEX IF NOT EXISTS idx_profiles_role_status 
ON profiles (role, status);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id 
ON profiles (user_id);

-- Index for drivers table (approval and online status)
CREATE INDEX IF NOT EXISTS idx_drivers_approval_status 
ON drivers (approval_status);

CREATE INDEX IF NOT EXISTS idx_drivers_online_status 
ON drivers (online_status);

CREATE INDEX IF NOT EXISTS idx_drivers_profile_id 
ON drivers (profile_id);

-- Index for trips table (real-time trip management)
CREATE INDEX IF NOT EXISTS idx_trips_status_created 
ON trips (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_driver_id_status 
ON trips (driver_id, status);

CREATE INDEX IF NOT EXISTS idx_trips_customer_id_status 
ON trips (customer_id, status);

-- Index for wallet_transactions table (wallet operations)
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_driver_id_created 
ON wallet_transactions (driver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type_status 
ON wallet_transactions (transaction_type, status);

-- Index for push_notifications table (delivery tracking)
CREATE INDEX IF NOT EXISTS idx_push_notifications_status_created 
ON push_notifications (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_push_notifications_driver_id_status 
ON push_notifications (driver_id, status);

-- Index for session_logs table (session management)
CREATE INDEX IF NOT EXISTS idx_session_logs_user_id_timestamp 
ON session_logs (user_id, timestamp DESC);

-- Index for driver_approval_history table (approval workflow)
CREATE INDEX IF NOT EXISTS idx_driver_approval_history_driver_id_status 
ON driver_approval_history (driver_id, status);

CREATE INDEX IF NOT EXISTS idx_driver_approval_history_created_at 
ON driver_approval_history (created_at DESC);

-- Composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_drivers_composite_approval_online 
ON drivers (approval_status, online_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_composite_driver_status 
ON trips (driver_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wallet_composite_driver_type 
ON wallet_transactions (driver_id, transaction_type, created_at DESC);

-- Partial indexes for specific query patterns
CREATE INDEX IF NOT EXISTS idx_trips_active_drivers 
ON trips (driver_id) 
WHERE status IN ('requested', 'accepted', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_drivers_approved_online 
ON drivers (profile_id) 
WHERE approval_status = 'approved' AND online_status = true;

-- Index for FCM token management
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id_active 
ON fcm_tokens (user_id, is_active);

-- Index for realtime subscriptions
CREATE INDEX IF NOT EXISTS idx_realtime_subscriptions_channel_user 
ON realtime_subscriptions (channel, user_id);

-- Index for performance monitoring
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name_timestamp 
ON performance_metrics (metric_name, timestamp DESC);

-- Verify indexes were created successfully
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
AND tablename IN (
    'telemetry_logs', 'profiles', 'drivers', 'trips', 
    'wallet_transactions', 'push_notifications', 'session_logs',
    'driver_approval_history', 'fcm_tokens', 'realtime_subscriptions',
    'performance_metrics'
)
ORDER BY tablename, indexname;