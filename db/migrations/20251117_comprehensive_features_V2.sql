-- =====================================================
-- AlboCarRide Comprehensive Features Migration V2
-- Date: 2025-11-17
-- Clean version with proper IF EXISTS checks
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CLEANUP: Drop existing objects if they exist
-- =====================================================

-- Drop triggers first (with IF EXISTS)
DO $$
BEGIN
    DROP TRIGGER IF EXISTS update_saved_addresses_updated_at ON public.saved_addresses;
    DROP TRIGGER IF EXISTS update_driver_mobile_money_updated_at ON public.driver_mobile_money;
    DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at ON public.emergency_contacts;
    DROP TRIGGER IF EXISTS update_sos_incidents_updated_at ON public.sos_incidents;
    DROP TRIGGER IF EXISTS update_wallet_commission_payments_updated_at ON public.wallet_commission_payments;
    DROP TRIGGER IF EXISTS update_trip_payments_updated_at ON public.trip_payments;
    DROP TRIGGER IF EXISTS ensure_single_primary_mobile_money_trigger ON public.driver_mobile_money;
    DROP TRIGGER IF EXISTS deduct_trip_commission_trigger ON public.trip_payments;
EXCEPTION WHEN OTHERS THEN
    NULL; -- Ignore errors if triggers don't exist
END $$;

-- Drop functions (with IF EXISTS)
DROP FUNCTION IF EXISTS upsert_recent_destination(UUID, TEXT, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS ensure_single_primary_mobile_money();
DROP FUNCTION IF EXISTS deduct_trip_commission();

-- Drop tables (with CASCADE to remove dependencies)
DROP TABLE IF EXISTS public.trip_payments CASCADE;
DROP TABLE IF EXISTS public.wallet_commission_payments CASCADE;
DROP TABLE IF EXISTS public.sos_incidents CASCADE;
DROP TABLE IF EXISTS public.emergency_contacts CASCADE;
DROP TABLE IF EXISTS public.driver_mobile_money CASCADE;
DROP TABLE IF EXISTS public.recent_destinations CASCADE;
DROP TABLE IF EXISTS public.saved_addresses CASCADE;

-- =====================================================
-- 1. SAVED ADDRESSES TABLE
-- =====================================================
CREATE TABLE public.saved_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    address_type TEXT CHECK (address_type IN ('home', 'work', 'other')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_saved_addresses_user ON public.saved_addresses(user_id);
CREATE INDEX idx_saved_addresses_type ON public.saved_addresses(address_type);

-- =====================================================
-- 2. RECENT DESTINATIONS TABLE
-- =====================================================
CREATE TABLE public.recent_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    visit_count INTEGER DEFAULT 1,
    last_visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_recent_destinations_user ON public.recent_destinations(user_id);
CREATE INDEX idx_recent_destinations_last_visited ON public.recent_destinations(last_visited_at DESC);
CREATE UNIQUE INDEX idx_recent_destinations_user_address ON public.recent_destinations(user_id, address);

-- =====================================================
-- 3. DRIVER MOBILE MONEY TABLE
-- =====================================================
CREATE TABLE public.driver_mobile_money (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('mpesa', 'orange_money', 'airtel_money')),
    phone_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_driver_mobile_money_driver ON public.driver_mobile_money(driver_id);
CREATE INDEX idx_driver_mobile_money_provider ON public.driver_mobile_money(provider);
CREATE INDEX idx_driver_mobile_money_primary ON public.driver_mobile_money(is_primary);

-- =====================================================
-- 4. EMERGENCY CONTACTS TABLE
-- =====================================================
CREATE TABLE public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    relationship TEXT,
    priority_order INTEGER NOT NULL DEFAULT 1 CHECK (priority_order >= 1 AND priority_order <= 3),
    notify_via_sms BOOLEAN DEFAULT TRUE,
    notify_via_whatsapp BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, priority_order)
);

CREATE INDEX idx_emergency_contacts_user ON public.emergency_contacts(user_id);
CREATE INDEX idx_emergency_contacts_priority ON public.emergency_contacts(priority_order);

-- =====================================================
-- 5. SOS INCIDENTS TABLE
-- =====================================================
CREATE TABLE public.sos_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_role TEXT NOT NULL CHECK (user_role IN ('customer', 'driver')),
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    location_address TEXT,
    incident_type TEXT DEFAULT 'emergency' CHECK (incident_type IN ('emergency', 'safety_concern', 'accident', 'harassment', 'other')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'false_alarm', 'cancelled')),
    notified_contacts JSONB,
    notified_drivers JSONB,
    responding_users JSONB,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    device_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sos_incidents_user ON public.sos_incidents(user_id);
CREATE INDEX idx_sos_incidents_status ON public.sos_incidents(status);
CREATE INDEX idx_sos_incidents_created ON public.sos_incidents(created_at DESC);
CREATE INDEX idx_sos_incidents_trip ON public.sos_incidents(trip_id);
CREATE INDEX idx_sos_incidents_location ON public.sos_incidents(latitude, longitude);

-- =====================================================
-- 6. WALLET COMMISSION PAYMENTS TABLE
-- =====================================================
CREATE TABLE public.wallet_commission_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('bank_transfer', 'mpesa', 'orange_money', 'airtel_money', 'cash')),
    transaction_reference TEXT,
    payment_proof_url TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    driver_notes TEXT,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_wallet_commission_payments_driver ON public.wallet_commission_payments(driver_id);
CREATE INDEX idx_wallet_commission_payments_status ON public.wallet_commission_payments(status);
CREATE INDEX idx_wallet_commission_payments_created ON public.wallet_commission_payments(created_at DESC);

-- =====================================================
-- 7. TRIP PAYMENTS TABLE
-- =====================================================
CREATE TABLE public.trip_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    commission_amount NUMERIC(10, 2) NOT NULL,
    driver_net_amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa', 'orange_money', 'airtel_money', 'cash', 'card')),
    driver_mobile_money_id UUID REFERENCES public.driver_mobile_money(id) ON DELETE SET NULL,
    driver_phone_number TEXT,
    customer_confirmed BOOLEAN DEFAULT FALSE,
    customer_confirmed_at TIMESTAMP WITH TIME ZONE,
    driver_confirmed BOOLEAN DEFAULT FALSE,
    driver_confirmed_at TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'customer_confirmed', 'completed', 'disputed', 'failed')),
    disputed_by TEXT CHECK (disputed_by IN ('customer', 'driver')),
    dispute_reason TEXT,
    dispute_resolved BOOLEAN DEFAULT FALSE,
    dispute_resolution TEXT,
    transaction_reference TEXT,
    commission_deducted BOOLEAN DEFAULT FALSE,
    commission_deducted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(trip_id)
);

CREATE INDEX idx_trip_payments_trip ON public.trip_payments(trip_id);
CREATE INDEX idx_trip_payments_customer ON public.trip_payments(customer_id);
CREATE INDEX idx_trip_payments_driver ON public.trip_payments(driver_id);
CREATE INDEX idx_trip_payments_status ON public.trip_payments(status);
CREATE INDEX idx_trip_payments_created ON public.trip_payments(created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recent_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_mobile_money ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_commission_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_payments ENABLE ROW LEVEL SECURITY;

-- Saved Addresses Policies
CREATE POLICY "Users can view their own saved addresses" ON public.saved_addresses FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own saved addresses" ON public.saved_addresses FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own saved addresses" ON public.saved_addresses FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own saved addresses" ON public.saved_addresses FOR DELETE USING (auth.uid() = user_id);

-- Recent Destinations Policies
CREATE POLICY "Users can view their own recent destinations" ON public.recent_destinations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own recent destinations" ON public.recent_destinations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own recent destinations" ON public.recent_destinations FOR UPDATE USING (auth.uid() = user_id);

-- Driver Mobile Money Policies
CREATE POLICY "Drivers can view their own mobile money details" ON public.driver_mobile_money FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can create their own mobile money details" ON public.driver_mobile_money FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers can update their own mobile money details" ON public.driver_mobile_money FOR UPDATE USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can delete their own mobile money details" ON public.driver_mobile_money FOR DELETE USING (auth.uid() = driver_id);
CREATE POLICY "Customers can view driver mobile money during trip" ON public.driver_mobile_money FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.trips
        WHERE driver_id = driver_mobile_money.driver_id
        AND customer_id = auth.uid()
        AND status IN ('accepted', 'arrived', 'started')
    )
);

-- Emergency Contacts Policies
CREATE POLICY "Users can manage their own emergency contacts" ON public.emergency_contacts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- SOS Incidents Policies
CREATE POLICY "Users can view their own SOS incidents" ON public.sos_incidents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own SOS incidents" ON public.sos_incidents FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own SOS incidents" ON public.sos_incidents FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Drivers can view SOS incidents they were notified about" ON public.sos_incidents FOR SELECT USING (
    user_role = 'driver' AND notified_drivers ? auth.uid()::text
);

-- Wallet Commission Payments Policies
CREATE POLICY "Drivers can view their own commission payments" ON public.wallet_commission_payments FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can create their own commission payments" ON public.wallet_commission_payments FOR INSERT WITH CHECK (auth.uid() = driver_id);

-- Trip Payments Policies
CREATE POLICY "Users can view their own trip payments" ON public.trip_payments FOR SELECT USING (auth.uid() = customer_id OR auth.uid() = driver_id);
CREATE POLICY "System can create trip payments" ON public.trip_payments FOR INSERT WITH CHECK (auth.uid() = customer_id OR auth.uid() = driver_id);
CREATE POLICY "Users can update trip payments they're involved in" ON public.trip_payments FOR UPDATE USING (auth.uid() = customer_id OR auth.uid() = driver_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Ensure update_updated_at_column function exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        CREATE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
    END IF;
END $$;

-- Create triggers
CREATE TRIGGER update_saved_addresses_updated_at BEFORE UPDATE ON public.saved_addresses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_driver_mobile_money_updated_at BEFORE UPDATE ON public.driver_mobile_money FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_emergency_contacts_updated_at BEFORE UPDATE ON public.emergency_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sos_incidents_updated_at BEFORE UPDATE ON public.sos_incidents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_wallet_commission_payments_updated_at BEFORE UPDATE ON public.wallet_commission_payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trip_payments_updated_at BEFORE UPDATE ON public.trip_payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Upsert recent destination function
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
    UPDATE public.recent_destinations
    SET visit_count = visit_count + 1, last_visited_at = NOW()
    WHERE user_id = p_user_id AND address = p_address
    RETURNING id INTO v_destination_id;

    IF v_destination_id IS NULL THEN
        INSERT INTO public.recent_destinations (user_id, address, latitude, longitude)
        VALUES (p_user_id, p_address, p_latitude, p_longitude)
        RETURNING id INTO v_destination_id;
    END IF;

    RETURN v_destination_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure single primary mobile money account
CREATE OR REPLACE FUNCTION ensure_single_primary_mobile_money()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_primary = TRUE THEN
        UPDATE public.driver_mobile_money
        SET is_primary = FALSE
        WHERE driver_id = NEW.driver_id AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_primary_mobile_money_trigger
    BEFORE INSERT OR UPDATE ON public.driver_mobile_money
    FOR EACH ROW WHEN (NEW.is_primary = TRUE)
    EXECUTE FUNCTION ensure_single_primary_mobile_money();

-- Deduct commission function
CREATE OR REPLACE FUNCTION deduct_trip_commission()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND NEW.commission_deducted = FALSE THEN
        UPDATE public.driver_wallet
        SET balance = balance - NEW.commission_amount
        WHERE driver_id = NEW.driver_id;

        INSERT INTO public.wallet_transactions (driver_id, trip_id, amount, type, status, description)
        VALUES (NEW.driver_id, NEW.trip_id, -NEW.commission_amount, 'commission', 'completed', 'Commission deducted for trip ' || NEW.trip_id);

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
-- SUCCESS!
-- =====================================================
