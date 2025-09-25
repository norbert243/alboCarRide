-- Complete Database Migration for AlboCarRide
-- This script includes both schema creation and RLS policies

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS driver_documents CASCADE;
DROP TABLE IF EXISTS ride_locations CASCADE;
DROP TABLE IF EXISTS driver_earnings CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS rides CASCADE;
DROP TABLE IF EXISTS ride_requests CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
DROP TRIGGER IF EXISTS update_drivers_updated_at ON drivers;
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
DROP TRIGGER IF EXISTS update_rides_updated_at ON rides;
DROP TRIGGER IF EXISTS update_payments_updated_at ON payments;
DROP TRIGGER IF EXISTS update_driver_earnings_updated_at ON driver_earnings;
DROP TRIGGER IF EXISTS update_driver_documents_updated_at ON driver_documents;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS is_admin(UUID) CASCADE;

-- Profiles table (user profiles with role information - references auth.users directly)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'driver')),
    avatar_url TEXT,
    verification_status VARCHAR(20) CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verification_submitted_at TIMESTAMP WITH TIME ZONE,
    is_online BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Driver-specific information
CREATE TABLE drivers (
    id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    license_number VARCHAR(100),
    license_expiry DATE,
    vehicle_type VARCHAR(20) CHECK (vehicle_type IN ('car', 'motorcycle')),
    vehicle_make VARCHAR(100),
    vehicle_model VARCHAR(100),
    vehicle_year INTEGER,
    vehicle_color VARCHAR(50),
    license_plate VARCHAR(20),
    current_latitude DECIMAL(10, 8),
    current_longitude DECIMAL(10, 8),
    rating DECIMAL(3, 2) DEFAULT 0.0,
    total_rides INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer-specific information
CREATE TABLE customers (
    id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    preferred_payment_method VARCHAR(50) DEFAULT 'cash',
    rating DECIMAL(3, 2) DEFAULT 0.0,
    total_rides INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ride requests table
CREATE TABLE ride_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    pickup_address TEXT NOT NULL,
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(10, 8) NOT NULL,
    dropoff_address TEXT NOT NULL,
    dropoff_latitude DECIMAL(10, 8) NOT NULL,
    dropoff_longitude DECIMAL(10, 8) NOT NULL,
    estimated_distance DECIMAL(8, 2),
    estimated_duration INTEGER,
    estimated_price DECIMAL(10, 2),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'driver_assigned', 'picked_up', 'in_progress', 'completed', 'cancelled')),
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT
);

-- Rides table (completed/accepted rides)
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_request_id UUID REFERENCES ride_requests(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    pickup_address TEXT NOT NULL,
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(10, 8) NOT NULL,
    dropoff_address TEXT NOT NULL,
    dropoff_latitude DECIMAL(10, 8) NOT NULL,
    dropoff_longitude DECIMAL(10, 8) NOT NULL,
    actual_distance DECIMAL(8, 2),
    actual_duration INTEGER,
    base_fare DECIMAL(10, 2) NOT NULL,
    distance_fare DECIMAL(10, 2),
    time_fare DECIMAL(10, 2),
    surge_multiplier DECIMAL(4, 2) DEFAULT 1.0,
    total_price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('scheduled', 'picked_up', 'in_progress', 'completed', 'cancelled')),
    scheduled_for TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5),
    driver_rating INTEGER CHECK (driver_rating BETWEEN 1 AND 5),
    customer_feedback TEXT,
    driver_feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payments table
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('cash', 'card', 'mobile_money')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    transaction_id VARCHAR(255),
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Driver earnings table
CREATE TABLE driver_earnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    commission DECIMAL(10, 2) NOT NULL,
    net_earnings DECIMAL(10, 2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'processing')),
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ride locations tracking (for real-time tracking)
CREATE TABLE ride_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(10, 8) NOT NULL,
    speed DECIMAL(6, 2),
    heading DECIMAL(5, 2),
    accuracy DECIMAL(6, 2),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Driver documents table
CREATE TABLE driver_documents (
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

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('ride_update', 'payment', 'promotion', 'system', 'verification')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_drivers_online ON drivers(is_online);
CREATE INDEX idx_drivers_location ON drivers(current_latitude, current_longitude);
CREATE INDEX idx_ride_requests_status ON ride_requests(status);
CREATE INDEX idx_ride_requests_customer ON ride_requests(customer_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_customer ON rides(customer_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
CREATE INDEX idx_payments_ride ON payments(ride_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_ride_locations_ride ON ride_locations(ride_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);

-- Triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rides_updated_at BEFORE UPDATE ON rides
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_earnings_updated_at BEFORE UPDATE ON driver_earnings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_documents_updated_at BEFORE UPDATE ON driver_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Drivers table policies
CREATE POLICY "Users can view own driver info" ON drivers
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own driver info" ON drivers
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own driver info" ON drivers
    FOR UPDATE USING (auth.uid() = id);

-- Customers table policies
CREATE POLICY "Users can view own customer info" ON customers
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own customer info" ON customers
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own customer info" ON customers
    FOR UPDATE USING (auth.uid() = id);

-- Ride requests policies
CREATE POLICY "Customers can view own ride requests" ON ride_requests
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Customers can insert own ride requests" ON ride_requests
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Customers can update own ride requests" ON ride_requests
    FOR UPDATE USING (auth.uid() = customer_id);

CREATE POLICY "Drivers can view available ride requests" ON ride_requests
    FOR SELECT USING (status = 'pending');

-- Rides policies
CREATE POLICY "Customers can view own rides" ON rides
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Drivers can view own rides" ON rides
    FOR SELECT USING (auth.uid() = driver_id);

-- Payments policies
CREATE POLICY "Customers can view own payments" ON payments
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Drivers can view own payments" ON payments
    FOR SELECT USING (auth.uid() = driver_id);

-- Driver earnings policies
CREATE POLICY "Drivers can view own earnings" ON driver_earnings
    FOR SELECT USING (auth.uid() = driver_id);

-- Ride locations policies
CREATE POLICY "Users can view ride locations for their rides" ON ride_locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM rides 
            WHERE rides.id = ride_locations.ride_id 
            AND (rides.customer_id = auth.uid() OR rides.driver_id = auth.uid())
        )
    );

-- Driver documents policies
CREATE POLICY "Users can view own documents" ON driver_documents
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own documents" ON driver_documents
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents" ON driver_documents
    FOR UPDATE USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Function to check if user is admin (placeholder)
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample data (optional)
-- Note: These sample profiles would require corresponding auth.users entries
-- INSERT INTO profiles (id, full_name, phone, role, verification_status) VALUES
-- ('00000000-0000-0000-0000-000000000001', 'System Admin', '+1234567890', 'customer', 'approved'),
-- ('00000000-0000-0000-0000-000000000002', 'John Driver', '+1234567891', 'driver', 'approved'),
-- ('00000000-0000-0000-0000-000000000003', 'Sarah Customer', '+1234567892', 'customer', 'approved');

-- INSERT INTO drivers (id, license_number, vehicle_type, vehicle_make, vehicle_model, license_plate) VALUES
-- ('00000000-0000-0000-0000-000000000002', 'DRV123456', 'car', 'Toyota', 'Corolla', 'ABC123');

-- INSERT INTO customers (id, preferred_payment_method) VALUES
-- ('00000000-0000-0000-0000-000000000003', 'card');