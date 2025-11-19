-- =====================================================
-- DIAGNOSTIC CHECK - Run this FIRST to find conflicts
-- =====================================================

-- Check existing tables
SELECT 'Existing Tables:' as info;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'saved_addresses',
    'recent_destinations',
    'driver_mobile_money',
    'emergency_contacts',
    'sos_incidents',
    'wallet_commission_payments',
    'trip_payments'
  );

-- Check existing functions
SELECT 'Existing Functions:' as info;
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'upsert_recent_destination',
    'ensure_single_primary_mobile_money',
    'deduct_trip_commission'
  );

-- Check existing triggers
SELECT 'Existing Triggers:' as info;
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%commission%';

-- Check for problematic policies
SELECT 'Existing Policies:' as info;
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename IN ('trip_payments', 'wallet_commission_payments');

-- Check trip_payments table structure if it exists
SELECT 'Trip Payments Columns (if table exists):' as info;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'trip_payments'
ORDER BY ordinal_position;
