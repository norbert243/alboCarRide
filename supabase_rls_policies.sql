-- Row Level Security Policies for AlboCarRide
-- Run this in your Supabase SQL Editor

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Profiles table policies
-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Drivers table policies
-- Users can insert their own driver profile
CREATE POLICY "Users can insert own driver profile"
ON drivers FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Drivers can view their own driver profile
CREATE POLICY "Drivers can view own profile"
ON drivers FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Drivers can update their own driver profile
CREATE POLICY "Drivers can update own profile"
ON drivers FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Customers table policies
-- Users can insert their own customer profile
CREATE POLICY "Users can insert own customer profile"
ON customers FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Customers can view their own customer profile
CREATE POLICY "Customers can view own profile"
ON customers FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Customers can update their own customer profile
CREATE POLICY "Customers can update own profile"
ON customers FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Ride requests policies
-- Customers can create ride requests
CREATE POLICY "Customers can create ride requests"
ON ride_requests FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid());

-- Users can view their own ride requests
CREATE POLICY "Users can view own ride requests"
ON ride_requests FOR SELECT
TO authenticated
USING (customer_id = auth.uid());

-- Basic policies for other tables (customize as needed)
CREATE POLICY "Users can view own rides"
ON rides FOR SELECT
TO authenticated
USING (customer_id = auth.uid() OR driver_id = auth.uid());

CREATE POLICY "Users can view own payments"
ON payments FOR SELECT
TO authenticated
USING (customer_id = auth.uid() OR driver_id = auth.uid());

CREATE POLICY "Drivers can view own earnings"
ON driver_earnings FOR SELECT
TO authenticated
USING (driver_id = auth.uid());

CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Allow service role for administrative tasks (optional)
CREATE POLICY "Service role full access"
ON ALL TABLES
TO service_role
USING (true)
WITH CHECK (true);