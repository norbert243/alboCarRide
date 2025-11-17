-- =====================================================
-- AlboCarRide Comprehensive Features Migration
-- Date: 2025-11-17
-- Features: Saved Addresses, Recent Destinations, Mobile Money, Emergency SOS
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. SAVED ADDRESSES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.saved_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Address details
    label TEXT NOT NULL, -- 'Home', 'Work', 'Custom Name'
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),

    -- Address type for quick filtering
    address_type TEXT CHECK (address_type IN ('home', 'work', 'other')),

    -- Additional info
    notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_saved_addresses_user ON public.saved_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_addresses_type ON public.saved_addresses(address_type);

-- =====================================================
-- 2. RECENT DESTINATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.recent_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Destination details
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),

    -- Track frequency and recency
    visit_count INTEGER DEFAULT 1,
    last_visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recent_destinations_user ON public.recent_destinations(user_id);
CREATE INDEX IF NOT EXISTS idx_recent_destinations_last_visited ON public.recent_destinations(last_visited_at DESC);

-- Unique constraint to prevent duplicate addresses per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_recent_destinations_user_address
    ON public.recent_destinations(user_id, address);

-- =====================================================
-- 3. DRIVER MOBILE MONEY DETAILS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.driver_mobile_money (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Mobile Money Details
    provider TEXT NOT NULL CHECK (provider IN ('mpesa', 'orange_money', 'airtel_money')),
    phone_number TEXT NOT NULL,
    account_name TEXT NOT NULL, -- Name registered on the mobile money account

    -- Preference and status
    is_primary BOOLEAN DEFAULT FALSE, -- Primary payment method
    is_active BOOLEAN DEFAULT TRUE,

    -- Verification (for future use)
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_driver_mobile_money_driver ON public.driver_mobile_money(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_mobile_money_provider ON public.driver_mobile_money(provider);
CREATE INDEX IF NOT EXISTS idx_driver_mobile_money_primary ON public.driver_mobile_money(is_primary);

-- =====================================================
-- 4. EMERGENCY CONTACTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Contact details
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    relationship TEXT, -- 'spouse', 'parent', 'sibling', 'friend', etc.

    -- Priority order (1 = primary contact)
    priority_order INTEGER NOT NULL DEFAULT 1 CHECK (priority_order >= 1 AND priority_order <= 3),

    -- Contact preferences
    notify_via_sms BOOLEAN DEFAULT TRUE,
    notify_via_whatsapp BOOLEAN DEFAULT TRUE,

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure max 3 contacts per user
    UNIQUE(user_id, priority_order)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON public.emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_priority ON public.emergency_contacts(priority_order);

-- =====================================================
-- 5. SOS INCIDENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.sos_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Who triggered the SOS
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_role TEXT NOT NULL CHECK (user_role IN ('customer', 'driver')),

    -- Related trip (if applicable)
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,

    -- Location at time of SOS
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    location_address TEXT,

    -- SOS Details
    incident_type TEXT DEFAULT 'emergency' CHECK (incident_type IN ('emergency', 'safety_concern', 'accident', 'harassment', 'other')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'false_alarm', 'cancelled')),

    -- Response tracking
    notified_contacts JSONB, -- Array of contact IDs that were notified
    notified_drivers JSONB, -- Array of driver IDs that received the alert (for driver SOS)
    responding_users JSONB, -- Users who responded/acknowledged

    -- Resolution
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolution_notes TEXT,

    -- Metadata
    device_info JSONB, -- Device type, app version, etc.

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sos_incidents_user ON public.sos_incidents(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_incidents_status ON public.sos_incidents(status);
CREATE INDEX IF NOT EXISTS idx_sos_incidents_created ON public.sos_incidents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_incidents_trip ON public.sos_incidents(trip_id);

-- Spatial index for finding nearby drivers during driver SOS
CREATE INDEX IF NOT EXISTS idx_sos_incidents_location ON public.sos_incidents(latitude, longitude);

-- =====================================================
-- 6. WALLET COMMISSION PAYMENTS TABLE (Driver Top-ups)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.wallet_commission_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Payment details
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('bank_transfer', 'mpesa', 'orange_money', 'airtel_money', 'cash')),

    -- Reference and proof
    transaction_reference TEXT, -- Driver provided reference number
    payment_proof_url TEXT, -- Screenshot/receipt upload

    -- Admin verification
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,

    -- Notes
    driver_notes TEXT,
    admin_notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wallet_commission_payments_driver ON public.wallet_commission_payments(driver_id);
CREATE INDEX IF NOT EXISTS idx_wallet_commission_payments_status ON public.wallet_commission_payments(status);
CREATE INDEX IF NOT EXISTS idx_wallet_commission_payments_created ON public.wallet_commission_payments(created_at DESC);

-- =====================================================
-- 7. TRIP PAYMENTS TABLE (Customer P2P to Driver)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.trip_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Payment details
    amount NUMERIC(10, 2) NOT NULL,
    commission_amount NUMERIC(10, 2) NOT NULL,
    driver_net_amount NUMERIC(10, 2) NOT NULL, -- amount - commission

    -- Mobile Money Details
    payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa', 'orange_money', 'airtel_money', 'cash', 'card')),
    driver_mobile_money_id UUID REFERENCES public.driver_mobile_money(id) ON DELETE SET NULL,
    driver_phone_number TEXT, -- The phone number customer paid to

    -- Payment flow
    customer_confirmed BOOLEAN DEFAULT FALSE, -- Customer confirmed they made payment
    customer_confirmed_at TIMESTAMP WITH TIME ZONE,

    driver_confirmed BOOLEAN DEFAULT FALSE, -- Driver confirmed they received payment
    driver_confirmed_at TIMESTAMP WITH TIME ZONE,

    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'customer_confirmed', 'completed', 'disputed', 'failed')),

    -- Dispute handling
    disputed_by TEXT CHECK (disputed_by IN ('customer', 'driver')),
    dispute_reason TEXT,
    dispute_resolved BOOLEAN DEFAULT FALSE,
    dispute_resolution TEXT,

    -- Transaction reference (if provided by customer)
    transaction_reference TEXT,

    -- Commission deduction tracking
    commission_deducted BOOLEAN DEFAULT FALSE,
    commission_deducted_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(trip_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trip_payments_trip ON public.trip_payments(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_payments_customer ON public.trip_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_trip_payments_driver ON public.trip_payments(driver_id);
CREATE INDEX IF NOT EXISTS idx_trip_payments_status ON public.trip_payments(status);
CREATE INDEX IF NOT EXISTS idx_trip_payments_created ON public.trip_payments(created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all new tables
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recent_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_mobile_money ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_commission_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_payments ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- SAVED ADDRESSES POLICIES
-- =====================================================
CREATE POLICY "Users can view their own saved addresses"
    ON public.saved_addresses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own saved addresses"
    ON public.saved_addresses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own saved addresses"
    ON public.saved_addresses FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own saved addresses"
    ON public.saved_addresses FOR DELETE
    USING (auth.uid() = user_id);

-- =====================================================
-- RECENT DESTINATIONS POLICIES
-- =====================================================
CREATE POLICY "Users can view their own recent destinations"
    ON public.recent_destinations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own recent destinations"
    ON public.recent_destinations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own recent destinations"
    ON public.recent_destinations FOR UPDATE
    USING (auth.uid() = user_id);

-- =====================================================
-- DRIVER MOBILE MONEY POLICIES
-- =====================================================
CREATE POLICY "Drivers can view their own mobile money details"
    ON public.driver_mobile_money FOR SELECT
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can create their own mobile money details"
    ON public.driver_mobile_money FOR INSERT
    WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers can update their own mobile money details"
    ON public.driver_mobile_money FOR UPDATE
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can delete their own mobile money details"
    ON public.driver_mobile_money FOR DELETE
    USING (auth.uid() = driver_id);

-- Customers can view driver's mobile money during active trip
CREATE POLICY "Customers can view driver mobile money during trip"
    ON public.driver_mobile_money FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.trips
            WHERE driver_id = driver_mobile_money.driver_id
            AND customer_id = auth.uid()
            AND status IN ('accepted', 'arrived', 'started')
        )
    );

-- =====================================================
-- EMERGENCY CONTACTS POLICIES
-- =====================================================
CREATE POLICY "Users can manage their own emergency contacts"
    ON public.emergency_contacts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- SOS INCIDENTS POLICIES
-- =====================================================
CREATE POLICY "Users can view their own SOS incidents"
    ON public.sos_incidents FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own SOS incidents"
    ON public.sos_incidents FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own SOS incidents"
    ON public.sos_incidents FOR UPDATE
    USING (auth.uid() = user_id);

-- Drivers can view SOS incidents where they were notified
CREATE POLICY "Drivers can view SOS incidents they were notified about"
    ON public.sos_incidents FOR SELECT
    USING (
        user_role = 'driver' AND
        notified_drivers ? auth.uid()::text
    );

-- =====================================================
-- WALLET COMMISSION PAYMENTS POLICIES
-- =====================================================
CREATE POLICY "Drivers can view their own commission payments"
    ON public.wallet_commission_payments FOR SELECT
    USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can create their own commission payments"
    ON public.wallet_commission_payments FOR INSERT
    WITH CHECK (auth.uid() = driver_id);

-- =====================================================
-- TRIP PAYMENTS POLICIES
-- =====================================================
CREATE POLICY "Users can view their own trip payments"
    ON public.trip_payments FOR SELECT
    USING (auth.uid() = customer_id OR auth.uid() = driver_id);

CREATE POLICY "System can create trip payments"
    ON public.trip_payments FOR INSERT
    WITH CHECK (auth.uid() = customer_id OR auth.uid() = driver_id);

CREATE POLICY "Users can update trip payments they're involved in"
    ON public.trip_payments FOR UPDATE
    USING (auth.uid() = customer_id OR auth.uid() = driver_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Trigger for updated_at on all new tables
CREATE TRIGGER update_saved_addresses_updated_at BEFORE UPDATE ON public.saved_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_mobile_money_updated_at BEFORE UPDATE ON public.driver_mobile_money
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_emergency_contacts_updated_at BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sos_incidents_updated_at BEFORE UPDATE ON public.sos_incidents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wallet_commission_payments_updated_at BEFORE UPDATE ON public.wallet_commission_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trip_payments_updated_at BEFORE UPDATE ON public.trip_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Function to update or increment recent destinations
-- =====================================================
CREATE OR REPLACE FUNCTION upsert_recent_destination(
    p_user_id UUID,
    p_address TEXT,
    p_latitude NUMERIC,
    p_longitude NUMERIC
)
RETURNS UUID AS $$
DECLARE
    v_destination_id UUID;
BEGIN
    -- Try to update existing destination
    UPDATE public.recent_destinations
    SET
        visit_count = visit_count + 1,
        last_visited_at = NOW()
    WHERE user_id = p_user_id
        AND address = p_address
    RETURNING id INTO v_destination_id;

    -- If no rows updated, insert new destination
    IF v_destination_id IS NULL THEN
        INSERT INTO public.recent_destinations (user_id, address, latitude, longitude)
        VALUES (p_user_id, p_address, p_latitude, p_longitude)
        RETURNING id INTO v_destination_id;
    END IF;

    RETURN v_destination_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Function to ensure only one primary mobile money account per driver
-- =====================================================
CREATE OR REPLACE FUNCTION ensure_single_primary_mobile_money()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_primary = TRUE THEN
        -- Set all other accounts for this driver to non-primary
        UPDATE public.driver_mobile_money
        SET is_primary = FALSE
        WHERE driver_id = NEW.driver_id
            AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_primary_mobile_money_trigger
    BEFORE INSERT OR UPDATE ON public.driver_mobile_money
    FOR EACH ROW
    WHEN (NEW.is_primary = TRUE)
    EXECUTE FUNCTION ensure_single_primary_mobile_money();

-- =====================================================
-- Function to deduct commission from driver wallet when payment is confirmed
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_trip_commission()
RETURNS TRIGGER AS $$
BEGIN
    -- When payment is fully confirmed (both customer and driver confirmed)
    IF NEW.status = 'completed' AND NEW.commission_deducted = FALSE THEN
        -- Deduct commission from driver wallet
        UPDATE public.driver_wallet
        SET balance = balance - NEW.commission_amount
        WHERE driver_id = NEW.driver_id;

        -- Record transaction
        INSERT INTO public.wallet_transactions (
            driver_id,
            trip_id,
            amount,
            type,
            status,
            description
        ) VALUES (
            NEW.driver_id,
            NEW.trip_id,
            -NEW.commission_amount,
            'commission',
            'completed',
            'Commission deducted for trip ' || NEW.trip_id
        );

        -- Mark commission as deducted
        NEW.commission_deducted = TRUE;
        NEW.commission_deducted_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER deduct_trip_commission_trigger
    BEFORE UPDATE ON public.trip_payments
    FOR EACH ROW
    EXECUTE FUNCTION deduct_trip_commission();

-- =====================================================
-- COMPLETE!
-- All tables and policies created successfully
-- =====================================================
