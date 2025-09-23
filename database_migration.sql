-- Database Migration Script for AlboCarRide
-- This script updates the existing database schema to support the new driver flow

-- Step 1: Add new columns to profiles table (without default value for verification_status)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS verification_status VARCHAR(20)
CHECK (verification_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE;

-- Step 2: Add vehicle_type column to drivers table and remove is_approved
ALTER TABLE drivers
ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(20)
CHECK (vehicle_type IN ('car', 'motorcycle'));

-- Remove is_approved column since we're using verification_status in profiles
ALTER TABLE drivers
DROP COLUMN IF EXISTS is_approved;

-- Step 3: Create driver_documents table if it doesn't exist
CREATE TABLE IF NOT EXISTS driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('driver_license', 'vehicle_registration', 'profile_photo', 'vehicle_photo')),
    document_url TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewer_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: Update existing profiles to set verification_status based on is_verified
-- Only set verification_status for profiles that have completed verification
UPDATE profiles
SET verification_status = CASE
    WHEN is_verified = TRUE THEN 'approved'
    ELSE NULL  -- Leave as NULL for profiles that haven't started verification
END;

-- Step 5: Update notifications table to include verification type
ALTER TABLE notifications
ALTER COLUMN user_id TYPE UUID USING user_id::UUID,
ALTER COLUMN user_id SET NOT NULL;

-- Drop the old foreign key constraint if it exists
ALTER TABLE notifications
DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

-- Add new foreign key constraint to profiles table
ALTER TABLE notifications
ADD CONSTRAINT notifications_user_id_fkey
FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- Add verification type to notifications if not already present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'notification_type_enum'
    ) THEN
        ALTER TABLE notifications
        DROP CONSTRAINT IF EXISTS notifications_type_check;
        
        ALTER TABLE notifications
        ADD CONSTRAINT notifications_type_check
        CHECK (type IN ('ride_update', 'payment', 'promotion', 'system', 'verification'));
    END IF;
END $$;

-- Step 6: Create trigger for driver_documents table
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_driver_documents_updated_at ON driver_documents;
CREATE TRIGGER update_driver_documents_updated_at BEFORE UPDATE ON driver_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 7: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_verification_status ON profiles(verification_status);
CREATE INDEX IF NOT EXISTS idx_profiles_online ON profiles(is_online);
CREATE INDEX IF NOT EXISTS idx_drivers_vehicle_type ON drivers(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_driver_documents_user ON driver_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON driver_documents(verification_status);

-- Step 8: Migration complete message
SELECT 'Database migration completed successfully!' as migration_status;