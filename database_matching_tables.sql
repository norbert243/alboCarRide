-- Database Migration Script for Ride Matching System
-- This script creates the necessary tables for the ride matching service

-- Create ride_requests table
CREATE TABLE IF NOT EXISTS ride_requests (
    id TEXT PRIMARY KEY,
    rider_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    pickup_address TEXT NOT NULL,
    dropoff_address TEXT NOT NULL,
    proposed_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled', 'failed')),
    pickup_lat DECIMAL(10,8),
    pickup_lng DECIMAL(11,8),
    dropoff_lat DECIMAL(10,8),
    dropoff_lng DECIMAL(11,8),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create ride_offers table (extended version for matching system)
CREATE TABLE IF NOT EXISTS ride_offers (
    id TEXT PRIMARY KEY,
    request_id TEXT NOT NULL REFERENCES ride_requests(id) ON DELETE CASCADE,
    driver_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    offer_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'countered', 'expired')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(request_id, driver_id) -- Prevent duplicate offers for same request
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ride_requests_rider_id ON ride_requests(rider_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON ride_requests(status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_created_at ON ride_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_ride_requests_location ON ride_requests(pickup_lat, pickup_lng);

CREATE INDEX IF NOT EXISTS idx_ride_offers_request_id ON ride_offers(request_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver_id ON ride_offers(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_status ON ride_offers(status);
CREATE INDEX IF NOT EXISTS idx_ride_offers_expires_at ON ride_offers(expires_at);

-- Create RLS policies for ride_requests
ALTER TABLE ride_requests ENABLE ROW LEVEL SECURITY;

-- Riders can only see their own requests
CREATE POLICY "Users can view own ride requests" ON ride_requests
    FOR SELECT USING (auth.uid() = rider_id);

-- Riders can insert their own requests
CREATE POLICY "Users can insert own ride requests" ON ride_requests
    FOR INSERT WITH CHECK (auth.uid() = rider_id);

-- Riders can update their own pending requests
CREATE POLICY "Users can update own ride requests" ON ride_requests
    FOR UPDATE USING (auth.uid() = rider_id AND status = 'pending');

-- Drivers can view ride requests (for matching service)
CREATE POLICY "Drivers can view ride requests" ON ride_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role = 'driver'
        )
    );

-- Create RLS policies for ride_offers
ALTER TABLE ride_offers ENABLE ROW LEVEL SECURITY;

-- Drivers can view their own offers
CREATE POLICY "Drivers can view own offers" ON ride_offers
    FOR SELECT USING (auth.uid() = driver_id);

-- Drivers can insert their own offers
CREATE POLICY "Drivers can insert own offers" ON ride_offers
    FOR INSERT WITH CHECK (auth.uid() = driver_id);

-- Drivers can update their own offers
CREATE POLICY "Drivers can update own offers" ON ride_offers
    FOR UPDATE USING (auth.uid() = driver_id);

-- Riders can view offers for their requests
CREATE POLICY "Riders can view offers for their requests" ON ride_offers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ride_requests 
            WHERE ride_requests.id = ride_offers.request_id 
            AND ride_requests.rider_id = auth.uid()
        )
    );

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_ride_requests_updated_at 
    BEFORE UPDATE ON ride_requests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ride_offers_updated_at 
    BEFORE UPDATE ON ride_offers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to handle offer acceptance atomically
CREATE OR REPLACE FUNCTION accept_offer_atomic(offer_id TEXT)
RETURNS SETOF ride_offers AS $$
DECLARE
    accepted_offer ride_offers%ROWTYPE;
    request_record ride_requests%ROWTYPE;
BEGIN
    -- Get the offer and lock it
    SELECT * INTO accepted_offer FROM ride_offers 
    WHERE id = offer_id AND status = 'pending'
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found or not pending';
    END IF;
    
    -- Get the associated request
    SELECT * INTO request_record FROM ride_requests 
    WHERE id = accepted_offer.request_id AND status = 'pending'
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found or not pending';
    END IF;
    
    -- Update the offer to accepted
    UPDATE ride_offers 
    SET status = 'accepted', updated_at = NOW()
    WHERE id = offer_id
    RETURNING * INTO accepted_offer;
    
    -- Update the request to accepted
    UPDATE ride_requests 
    SET status = 'accepted', updated_at = NOW()
    WHERE id = request_record.id;
    
    -- Expire all other offers for this request
    UPDATE ride_offers 
    SET status = 'expired', updated_at = NOW()
    WHERE request_id = request_record.id 
    AND status = 'pending' 
    AND id != offer_id;
    
    RETURN NEXT accepted_offer;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup expired offers and requests
CREATE OR REPLACE FUNCTION cleanup_expired_offers()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- Expire offers that have passed their expiration time
    UPDATE ride_offers 
    SET status = 'expired', updated_at = NOW()
    WHERE status = 'pending' AND expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    -- Expire requests that have no pending offers and are older than 15 minutes
    UPDATE ride_requests 
    SET status = 'expired', updated_at = NOW()
    WHERE status = 'pending' 
    AND created_at < NOW() - INTERVAL '15 minutes'
    AND NOT EXISTS (
        SELECT 1 FROM ride_offers 
        WHERE ride_offers.request_id = ride_requests.id 
        AND ride_offers.status = 'pending'
    );
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Create view for driver dashboard
CREATE OR REPLACE VIEW driver_offer_stats AS
SELECT 
    d.id as driver_id,
    COUNT(*) as total_offers,
    COUNT(CASE WHEN ro.status = 'pending' THEN 1 END) as pending_offers,
    COUNT(CASE WHEN ro.status = 'accepted' THEN 1 END) as accepted_offers,
    COUNT(CASE WHEN ro.status = 'rejected' THEN 1 END) as rejected_offers,
    AVG(CASE WHEN ro.status = 'accepted' THEN ro.offer_price END) as avg_accepted_price
FROM profiles d
LEFT JOIN ride_offers ro ON d.id = ro.driver_id
WHERE d.role = 'driver'
GROUP BY d.id;

-- Create view for rider request stats
CREATE OR REPLACE VIEW rider_request_stats AS
SELECT 
    r.id as rider_id,
    COUNT(*) as total_requests,
    COUNT(CASE WHEN rr.status = 'pending' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN rr.status = 'accepted' THEN 1 END) as accepted_requests,
    COUNT(CASE WHEN rr.status = 'expired' THEN 1 END) as expired_requests,
    AVG(rr.proposed_price) as avg_proposed_price
FROM profiles r
LEFT JOIN ride_requests rr ON r.id = rr.rider_id
WHERE r.role = 'rider'
GROUP BY r.id;

-- Insert sample data for testing (optional)
INSERT INTO ride_requests (id, rider_id, pickup_address, dropoff_address, proposed_price, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng) VALUES
('test_request_1', (SELECT id FROM profiles WHERE role = 'rider' LIMIT 1), '123 Main St', '456 Oak Ave', 15.00, 'pending', 40.7128, -74.0060, 40.7589, -73.9851),
('test_request_2', (SELECT id FROM profiles WHERE role = 'rider' LIMIT 1), '789 Pine St', '321 Elm St', 12.50, 'pending', 40.7505, -73.9934, 40.7282, -74.0776);

-- Create indexes for geospatial queries (if PostGIS is available)
-- CREATE INDEX IF NOT EXISTS idx_ride_requests_geog ON ride_requests USING GIST (ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326));
-- CREATE INDEX IF NOT EXISTS idx_drivers_geog ON drivers USING GIST (ST_SetSRID(ST_MakePoint(current_longitude, current_latitude), 4326));

COMMENT ON TABLE ride_requests IS 'Stores ride requests from customers';
COMMENT ON TABLE ride_offers IS 'Stores ride offers from drivers to customers';
COMMENT ON FUNCTION accept_offer_atomic IS 'Atomically accepts a ride offer and updates related records';
COMMENT ON FUNCTION cleanup_expired_offers IS 'Cleans up expired offers and requests';