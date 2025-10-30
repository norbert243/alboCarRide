-- ===========================================
-- DIAGNOSTIC: Ride Request System Check
-- ===========================================

-- 1. Check if ride_requests table exists
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name = 'ride_requests'
    AND table_schema = 'public';

-- 2. Check table structure if it exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'ride_requests'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if driver_accept_ride function exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'driver_accept_ride'
    AND routine_schema = 'public';

-- 4. Check for any existing ride requests
SELECT COUNT(*) as total_ride_requests FROM ride_requests;

-- 5. Check if realtime is enabled for ride_requests
SELECT 
    name,
    enabled
FROM supabase_realtime.realtime_subscriptions 
WHERE entity REGEXP 'ride_requests';

-- 6. Check driver online status
SELECT 
    id,
    is_online,
    created_at
FROM profiles 
WHERE role = 'driver'
ORDER BY created_at DESC
LIMIT 5;

-- 7. Create a test ride request if table exists
-- (Uncomment to test the system)
/*
INSERT INTO ride_requests (
    pickup_address,
    dropoff_address,
    proposed_price,
    customer_id,
    status,
    created_at
) VALUES (
    'Test Pickup Location',
    'Test Dropoff Location',
    25.00,
    (SELECT id FROM profiles WHERE role = 'customer' LIMIT 1),
    'pending',
    NOW()
) RETURNING *;
*/