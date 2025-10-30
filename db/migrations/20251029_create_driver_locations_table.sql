-- Migration: Create driver_locations table for real-time location tracking
-- This table stores driver GPS coordinates for ride matching

CREATE TABLE IF NOT EXISTS driver_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure one location record per driver
  UNIQUE(driver_id)
);

-- Create index for faster location-based queries
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_id ON driver_locations(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_updated_at ON driver_locations(updated_at);

-- Enable Row Level Security
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Drivers can only see their own location
CREATE POLICY "Drivers can view own location" ON driver_locations
  FOR SELECT USING (auth.uid() = driver_id);

-- Drivers can insert/update their own location
CREATE POLICY "Drivers can insert own location" ON driver_locations
  FOR INSERT WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can update own location" ON driver_locations
  FOR UPDATE USING (auth.uid() = driver_id);

-- Note: No DELETE policy as locations should be maintained for ride matching