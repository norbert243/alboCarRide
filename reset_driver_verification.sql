-- Reset Driver Verification Status Script
-- This script resets the verification status for driver profiles to allow testing the complete flow

-- Reset verification status for all driver profiles to NULL
-- This will allow them to go through the proper verification flow
UPDATE profiles 
SET verification_status = NULL,
    verification_submitted_at = NULL
WHERE role = 'driver';

-- Reset vehicle type for all drivers to allow testing vehicle selection
UPDATE drivers 
SET vehicle_type = NULL;

-- Clear any existing driver documents (optional - for clean testing)
DELETE FROM driver_documents;

-- Display the reset results
SELECT 
    'Verification status reset for driver profiles' as action,
    COUNT(*) as affected_profiles
FROM profiles 
WHERE role = 'driver' AND verification_status IS NULL;

SELECT 
    'Vehicle type reset for drivers' as action,
    COUNT(*) as affected_drivers
FROM drivers 
WHERE vehicle_type IS NULL;

SELECT 'Database reset completed successfully!' as status;