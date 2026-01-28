-- Migration: Database Cleanup and Fixes
-- Date: 2026-01-26
-- Description: Fix column naming, add missing RLS policies, clean up schema

-- ===========================================
-- 1) Fix driver_locations table column naming
-- ===========================================
-- The table uses latitude/longitude but the app expects lat/lng
-- Rename columns to match app expectations

DO $$
BEGIN
  -- Check if the old column names exist and rename them
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'driver_locations' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE driver_locations RENAME COLUMN latitude TO lat;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'driver_locations' AND column_name = 'longitude'
  ) THEN
    ALTER TABLE driver_locations RENAME COLUMN longitude TO lng;
  END IF;
END $$;

-- Add missing columns for better tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'driver_locations' AND column_name = 'speed'
  ) THEN
    ALTER TABLE driver_locations ADD COLUMN speed DOUBLE PRECISION;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'driver_locations' AND column_name = 'accuracy'
  ) THEN
    ALTER TABLE driver_locations ADD COLUMN accuracy DOUBLE PRECISION;
  END IF;
END $$;

-- ===========================================
-- 2) Add RLS policy for customers to view driver locations during active rides
-- ===========================================
-- Drop existing policies if they exist (to recreate them properly)
DROP POLICY IF EXISTS "Customers can view driver location during active ride" ON driver_locations;

-- Allow customers to view driver location when they have an active ride with that driver
CREATE POLICY "Customers can view driver location during active ride" ON driver_locations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM rides r
      WHERE r.driver_id = driver_locations.driver_id
        AND r.customer_id = auth.uid()
        AND r.status IN ('driver_assigned', 'accepted', 'driver_arrived', 'in_progress')
    )
  );

-- ===========================================
-- 3) Create driver_payment_details table if not exists and add RLS policies
-- ===========================================
CREATE TABLE IF NOT EXISTS driver_payment_details (
    id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    bank_name VARCHAR(255),
    account_number VARCHAR(100),
    branch_code VARCHAR(100),
    mobile_money_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE driver_payment_details ENABLE ROW LEVEL SECURITY;

-- Drivers can view their own payment details
DROP POLICY IF EXISTS "Drivers can view own payment details" ON driver_payment_details;
CREATE POLICY "Drivers can view own payment details" ON driver_payment_details
  FOR SELECT USING (auth.uid() = id);

-- Drivers can insert their own payment details
DROP POLICY IF EXISTS "Drivers can insert own payment details" ON driver_payment_details;
CREATE POLICY "Drivers can insert own payment details" ON driver_payment_details
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Drivers can update their own payment details
DROP POLICY IF EXISTS "Drivers can update own payment details" ON driver_payment_details;
CREATE POLICY "Drivers can update own payment details" ON driver_payment_details
  FOR UPDATE USING (auth.uid() = id);

-- Add trigger for updated_at
DROP TRIGGER IF EXISTS update_driver_payment_details_updated_at ON driver_payment_details;
CREATE TRIGGER update_driver_payment_details_updated_at
  BEFORE UPDATE ON driver_payment_details
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- 4) Add missing indexes for better query performance
-- ===========================================

-- Index for rides table common queries
CREATE INDEX IF NOT EXISTS idx_rides_customer_id ON rides(customer_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_created_at ON rides(created_at DESC);

-- Index for ride_requests table
CREATE INDEX IF NOT EXISTS idx_ride_requests_customer_id ON ride_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON ride_requests(status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_created_at ON ride_requests(created_at DESC);

-- Index for profiles table
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON profiles(is_online);

-- Index for drivers table
CREATE INDEX IF NOT EXISTS idx_drivers_is_online ON drivers(is_online);
-- Only create approval_status index if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'drivers' AND column_name = 'approval_status'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_drivers_approval_status ON drivers(approval_status);
  END IF;
END $$;

-- ===========================================
-- 5) Add function to clean up expired ride offers
-- ===========================================
CREATE OR REPLACE FUNCTION cleanup_expired_ride_offers()
RETURNS INTEGER
SECURITY DEFINER
AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  UPDATE ride_offers
  SET status = 'expired',
      updated_at = NOW()
  WHERE status = 'pending'
    AND expires_at IS NOT NULL
    AND expires_at < NOW();

  GET DIAGNOSTICS affected_count = ROW_COUNT;
  RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 6) calculate_eta function - SKIPPED (already exists in database)
-- ===========================================

-- ===========================================
-- 7) Add updated_at trigger function if not exists
-- ===========================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 8) Clean up any orphaned data
-- ===========================================

-- Mark old pending ride requests as expired (older than 30 minutes)
UPDATE ride_requests
SET status = 'expired',
    updated_at = NOW()
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '30 minutes';

-- Mark old pending ride offers as expired
UPDATE ride_offers
SET status = 'expired',
    updated_at = NOW()
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '15 minutes';

-- ===========================================
-- 9) Add comments for documentation
-- ===========================================
COMMENT ON TABLE driver_locations IS 'Real-time GPS locations for drivers. One record per driver (upsert).';
COMMENT ON TABLE driver_payment_details IS 'Bank and mobile money details for driver payouts.';
COMMENT ON TABLE driver_documents IS 'Driver verification documents (license, ID, insurance, etc).';
COMMENT ON TABLE ride_offers IS 'Price negotiations between drivers and customers.';

-- Migration completed
COMMENT ON FUNCTION cleanup_expired_ride_offers IS 'Marks pending ride offers past their expiration time as expired.';
