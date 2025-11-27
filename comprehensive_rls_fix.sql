-- Comprehensive RLS Policy Fix for AlboCarRide
-- This script ensures all tables have proper RLS policies

-- =====================================================
-- 1. PROFILES TABLE POLICIES
-- =====================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Drivers can view profiles" ON public.profiles;

-- Create new policies
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Drivers can view other profiles (for ride matching)
CREATE POLICY "Drivers can view profiles"
    ON public.profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'driver'
        )
    );

-- =====================================================
-- 2. RIDE REQUESTS TABLE POLICIES
-- =====================================================
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Customers can view their own requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Customers can create requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Customers can update their own requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Drivers can view pending requests" ON public.ride_requests;

-- Create new policies
CREATE POLICY "Customers can view their own requests"
    ON public.ride_requests FOR SELECT
    USING (auth.uid() = customer_id);

CREATE POLICY "Customers can create requests"
    ON public.ride_requests FOR INSERT
    WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Customers can update their own requests"
    ON public.ride_requests FOR UPDATE
    USING (auth.uid() = customer_id);

-- Drivers can view all pending requests
CREATE POLICY "Drivers can view pending requests"
    ON public.ride_requests FOR SELECT
    USING (
        status = 'pending' AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'driver'
        )
    );

-- =====================================================
-- 3. RIDE OFFERS TABLE POLICIES
-- =====================================================
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Drivers can view their own offers" ON public.ride_offers;
DROP POLICY IF EXISTS "Drivers can create offers" ON public.ride_offers;
DROP POLICY IF EXISTS "Drivers can update their own offers" ON public.ride_offers;
DROP POLICY IF EXISTS "Customers can view offers on their requests" ON public.ride_offers;

-- Create new policies
CREATE POLICY "Drivers can view their own offers"
    ON public.ride_offers FOR SELECT
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can create offers"
    ON public.ride_offers FOR INSERT
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can update their own offers"
    ON public.ride_offers FOR UPDATE
    USING (auth.uid() = driver_id);

-- Customers can view offers on their requests
CREATE POLICY "Customers can view offers on their requests"
    ON public.ride_offers FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.ride_requests
            WHERE id = ride_offers.ride_request_id
            AND customer_id = auth.uid()
        )
    );

-- =====================================================
-- 4. TRIPS TABLE POLICIES
-- =====================================================
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own trips" ON public.trips;
DROP POLICY IF EXISTS "Drivers can create trips" ON public.trips;
DROP POLICY IF EXISTS "Users can update their own trips" ON public.trips;

-- Create new policies
CREATE POLICY "Users can view their own trips"
    ON public.trips FOR SELECT
    USING (auth.uid() = customer_id OR auth.uid() = driver_id);

CREATE POLICY "Drivers can create trips"
    ON public.trips FOR INSERT
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Users can update their own trips"
    ON public.trips FOR UPDATE
    USING (auth.uid() = customer_id OR auth.uid() = driver_id);

-- =====================================================
-- 5. SERVICE ROLE POLICIES (Full access for admin)
-- =====================================================
-- Service role has full access to all tables
CREATE POLICY IF NOT EXISTS "Service role full access profiles"
    ON public.profiles
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Service role full access ride_requests"
    ON public.ride_requests
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Service role full access ride_offers"
    ON public.ride_offers
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Service role full access trips"
    ON public.trips
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- VERIFICATION
-- =====================================================
-- Verify RLS is enabled on all tables
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('profiles', 'ride_requests', 'ride_offers', 'trips');

-- Show current policies
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
AND tablename IN ('profiles', 'ride_requests', 'ride_offers', 'trips')
ORDER BY tablename, policyname;

COMMENT ON TABLE public.ride_requests IS 'Customer ride requests with comprehensive RLS policies';
COMMENT ON TABLE public.ride_offers IS 'Driver ride offers with RLS policies';
COMMENT ON TABLE public.trips IS 'Completed trips with user-specific access';