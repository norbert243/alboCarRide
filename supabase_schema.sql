-- =====================================================
-- AlboCarRide Database Schema for Supabase
-- inDrive-style ride-hailing with price negotiation
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. PROFILES TABLE (extends auth.users)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone_number TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('customer', 'driver')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Driver-specific fields
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    is_online BOOLEAN DEFAULT FALSE,
    rating NUMERIC(3, 2) DEFAULT 0.0,
    total_ratings INTEGER DEFAULT 0,

    -- Location tracking
    current_latitude NUMERIC(10, 8),
    current_longitude NUMERIC(11, 8),
    last_location_update TIMESTAMP WITH TIME ZONE
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_profiles_is_online ON public.profiles(is_online);

-- =====================================================
-- 2. DRIVERS TABLE (additional driver information)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    vehicle_type TEXT CHECK (vehicle_type IN ('car', 'motorcycle')),
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year INTEGER,
    vehicle_color TEXT,
    license_plate TEXT,
    license_number TEXT,
    license_expiry DATE,

    -- Verification documents
    id_document_url TEXT,
    license_document_url TEXT,
    vehicle_document_url TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. RIDE REQUESTS TABLE (Customer ride requests)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.ride_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Location details
    pickup_location TEXT NOT NULL,
    pickup_latitude NUMERIC(10, 8),
    pickup_longitude NUMERIC(11, 8),
    dropoff_location TEXT NOT NULL,
    dropoff_latitude NUMERIC(10, 8),
    dropoff_longitude NUMERIC(11, 8),

    -- Pricing (inDrive-style)
    estimated_fare NUMERIC(10, 2),
    suggested_price NUMERIC(10, 2) NOT NULL, -- Customer's proposed price

    -- Additional info
    notes TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'offered', 'accepted', 'cancelled', 'completed')),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ride_requests_customer ON public.ride_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON public.ride_requests(status);
CREATE INDEX IF NOT EXISTS idx_ride_requests_created ON public.ride_requests(created_at DESC);

-- =====================================================
-- 4. RIDE OFFERS TABLE (Driver offers/counter-offers)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.ride_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_request_id UUID NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    offer_price NUMERIC(10, 2) NOT NULL, -- Driver's offered/counter-offered price
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'countered', 'accepted', 'rejected')),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure one offer per driver per request
    UNIQUE(ride_request_id, driver_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ride_offers_request ON public.ride_offers(ride_request_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver ON public.ride_offers(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_status ON public.ride_offers(status);

-- =====================================================
-- 5. TRIPS TABLE (Actual rides in progress/completed)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Location details
    pickup_location TEXT NOT NULL,
    pickup_latitude NUMERIC(10, 8),
    pickup_longitude NUMERIC(11, 8),
    dropoff_location TEXT NOT NULL,
    dropoff_latitude NUMERIC(10, 8),
    dropoff_longitude NUMERIC(11, 8),

    -- Pricing
    final_price NUMERIC(10, 2) NOT NULL,
    commission_amount NUMERIC(10, 2) DEFAULT 0.0,

    -- Payment
    payment_method_id TEXT,
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'refunded', 'failed')),

    -- Trip status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'arrived', 'started', 'completed', 'cancelled')),

    -- Timestamps
    start_time TIMESTAMP WITH TIME ZONE,
    arrival_time TIMESTAMP WITH TIME ZONE,
    pickup_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,

    -- Ratings
    driver_rating NUMERIC(2, 1) CHECK (driver_rating >= 0 AND driver_rating <= 5),
    customer_rating NUMERIC(2, 1) CHECK (customer_rating >= 0 AND customer_rating <= 5),
    driver_review TEXT,
    customer_review TEXT,

    -- Distance/duration tracking
    distance_km NUMERIC(10, 2),
    duration_minutes INTEGER,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trips_customer ON public.trips(customer_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON public.trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_end_time ON public.trips(end_time DESC);
CREATE INDEX IF NOT EXISTS idx_trips_created ON public.trips(created_at DESC);

-- =====================================================
-- 6. PAYMENT METHODS TABLE (Saved customer payment methods)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Stripe payment method details
    stripe_payment_method_id TEXT,
    card_brand TEXT,
    card_last4 TEXT,
    card_exp_month INTEGER,
    card_exp_year INTEGER,

    is_default BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_payment_methods_customer ON public.payment_methods(customer_id);

-- =====================================================
-- 7. DRIVER WALLET TABLE (Driver earnings)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.driver_wallet (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    balance NUMERIC(10, 2) DEFAULT 0.0,
    total_earned NUMERIC(10, 2) DEFAULT 0.0,
    total_withdrawn NUMERIC(10, 2) DEFAULT 0.0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(driver_id)
);

-- =====================================================
-- 8. WALLET TRANSACTIONS TABLE (Transaction history)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,

    amount NUMERIC(10, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('earning', 'withdrawal', 'refund', 'commission')),
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    description TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_driver ON public.wallet_transactions(driver_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created ON public.wallet_transactions(created_at DESC);

-- =====================================================
-- 9. NOTIFICATIONS TABLE (Push notifications)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT CHECK (type IN ('ride_request', 'ride_offer', 'ride_accepted', 'ride_started', 'ride_completed', 'payment', 'general')),

    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(is_read);

-- =====================================================
-- 10. FCM TOKENS TABLE (Firebase Cloud Messaging)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT CHECK (device_type IN ('ios', 'android', 'web')),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, token)
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PROFILES POLICIES
-- =====================================================
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
-- DRIVERS POLICIES
-- =====================================================
CREATE POLICY "Drivers can view their own info"
    ON public.drivers FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Drivers can update their own info"
    ON public.drivers FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Drivers can insert their own info"
    ON public.drivers FOR INSERT
    WITH CHECK (auth.uid() = id);

-- =====================================================
-- RIDE REQUESTS POLICIES
-- =====================================================
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
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'driver'
        )
    );

-- =====================================================
-- RIDE OFFERS POLICIES
-- =====================================================
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
-- TRIPS POLICIES
-- =====================================================
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
-- PAYMENT METHODS POLICIES
-- =====================================================
CREATE POLICY "Customers can view their own payment methods"
    ON public.payment_methods FOR SELECT
    USING (auth.uid() = customer_id);

CREATE POLICY "Customers can add payment methods"
    ON public.payment_methods FOR INSERT
    WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Customers can update their own payment methods"
    ON public.payment_methods FOR UPDATE
    USING (auth.uid() = customer_id);

CREATE POLICY "Customers can delete their own payment methods"
    ON public.payment_methods FOR DELETE
    USING (auth.uid() = customer_id);

-- =====================================================
-- DRIVER WALLET POLICIES
-- =====================================================
CREATE POLICY "Drivers can view their own wallet"
    ON public.driver_wallet FOR SELECT
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can insert their own wallet"
    ON public.driver_wallet FOR INSERT
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can update their own wallet"
    ON public.driver_wallet FOR UPDATE
    USING (auth.uid() = driver_id);

-- =====================================================
-- WALLET TRANSACTIONS POLICIES
-- =====================================================
CREATE POLICY "Drivers can view their own transactions"
    ON public.wallet_transactions FOR SELECT
    USING (auth.uid() = driver_id);

-- =====================================================
-- NOTIFICATIONS POLICIES
-- =====================================================
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- =====================================================
-- FCM TOKENS POLICIES
-- =====================================================
CREATE POLICY "Users can manage their own tokens"
    ON public.fcm_tokens FOR ALL
    USING (auth.uid() = user_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON public.drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ride_requests_updated_at BEFORE UPDATE ON public.ride_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ride_offers_updated_at BEFORE UPDATE ON public.ride_offers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON public.trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON public.payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_wallet_updated_at BEFORE UPDATE ON public.driver_wallet
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fcm_tokens_updated_at BEFORE UPDATE ON public.fcm_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Function to update driver rating
-- =====================================================
CREATE OR REPLACE FUNCTION update_driver_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.driver_rating IS NOT NULL THEN
        UPDATE public.profiles
        SET
            total_ratings = total_ratings + 1,
            rating = (
                (rating * total_ratings + NEW.driver_rating) / (total_ratings + 1)
            )
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_driver_rating_on_trip
    AFTER UPDATE OF driver_rating ON public.trips
    FOR EACH ROW
    WHEN (NEW.driver_rating IS NOT NULL AND OLD.driver_rating IS NULL)
    EXECUTE FUNCTION update_driver_rating();

-- =====================================================
-- SEED DATA (Optional - for testing)
-- =====================================================

-- You can add test data here if needed

-- =====================================================
-- COMPLETE!
-- Your database is now ready for the inDrive-style app
-- =====================================================
