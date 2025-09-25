-- Row-Level Security (RLS) Policies for AlboCarRide Database
-- These policies ensure proper access control for all tables

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Profiles table policies
-- Users can read their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Drivers table policies
-- Users can read their own driver info
CREATE POLICY "Users can view own driver info" ON drivers
    FOR SELECT USING (auth.uid() = id);

-- Users can insert their own driver info
CREATE POLICY "Users can insert own driver info" ON drivers
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own driver info
CREATE POLICY "Users can update own driver info" ON drivers
    FOR UPDATE USING (auth.uid() = id);

-- Customers table policies
-- Users can read their own customer info
CREATE POLICY "Users can view own customer info" ON customers
    FOR SELECT USING (auth.uid() = id);

-- Users can insert their own customer info
CREATE POLICY "Users can insert own customer info" ON customers
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own customer info
CREATE POLICY "Users can update own customer info" ON customers
    FOR UPDATE USING (auth.uid() = id);

-- Ride requests policies
-- Customers can view their own ride requests
CREATE POLICY "Customers can view own ride requests" ON ride_requests
    FOR SELECT USING (auth.uid() = customer_id);

-- Customers can insert their own ride requests
CREATE POLICY "Customers can insert own ride requests" ON ride_requests
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Customers can update their own ride requests
CREATE POLICY "Customers can update own ride requests" ON ride_requests
    FOR UPDATE USING (auth.uid() = customer_id);

-- Drivers can view ride requests (for accepting rides)
CREATE POLICY "Drivers can view available ride requests" ON ride_requests
    FOR SELECT USING (status = 'pending');

-- Rides policies
-- Customers can view their own rides
CREATE POLICY "Customers can view own rides" ON rides
    FOR SELECT USING (auth.uid() = customer_id);

-- Drivers can view their own rides
CREATE POLICY "Drivers can view own rides" ON rides
    FOR SELECT USING (auth.uid() = driver_id);

-- Payments policies
-- Customers can view their own payments
CREATE POLICY "Customers can view own payments" ON payments
    FOR SELECT USING (auth.uid() = customer_id);

-- Drivers can view their own payments
CREATE POLICY "Drivers can view own payments" ON payments
    FOR SELECT USING (auth.uid() = driver_id);

-- Driver earnings policies
-- Drivers can view their own earnings
CREATE POLICY "Drivers can view own earnings" ON driver_earnings
    FOR SELECT USING (auth.uid() = driver_id);

-- Ride locations policies
-- Customers and drivers can view ride locations for their rides
CREATE POLICY "Users can view ride locations for their rides" ON ride_locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM rides 
            WHERE rides.id = ride_locations.ride_id 
            AND (rides.customer_id = auth.uid() OR rides.driver_id = auth.uid())
        )
    );

-- Driver documents policies
-- Users can view their own documents
CREATE POLICY "Users can view own documents" ON driver_documents
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own documents
CREATE POLICY "Users can insert own documents" ON driver_documents
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own documents
CREATE POLICY "Users can update own documents" ON driver_documents
    FOR UPDATE USING (auth.uid() = user_id);

-- Notifications policies
-- Users can view their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own notifications (for system notifications)
CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Additional policies for admin access (if needed)
-- Note: These would require setting up admin roles in your auth system

-- Allow service role to bypass RLS (for server-side operations)
-- This is typically handled by using the service role key instead of anon key

-- Function to check if user is admin (placeholder - implement based on your auth setup)
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Implement your admin check logic here
    -- For now, return false - you'll need to implement this based on your user management
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;