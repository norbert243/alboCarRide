-- =====================================================
-- AlboCarRide Features - FINAL WORKING VERSION
-- No dependencies on trips table structure
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CLEANUP
-- =====================================================
DROP TABLE IF EXISTS public.trip_payments CASCADE;
DROP TABLE IF EXISTS public.wallet_commission_payments CASCADE;
DROP TABLE IF EXISTS public.sos_incidents CASCADE;
DROP TABLE IF EXISTS public.emergency_contacts CASCADE;
DROP TABLE IF EXISTS public.driver_mobile_money CASCADE;
DROP TABLE IF EXISTS public.recent_destinations CASCADE;
DROP TABLE IF EXISTS public.saved_addresses CASCADE;
DROP FUNCTION IF EXISTS upsert_recent_destination(UUID, TEXT, NUMERIC, NUMERIC) CASCADE;
DROP FUNCTION IF EXISTS ensure_single_primary_mobile_money() CASCADE;

-- =====================================================
-- 1. SAVED ADDRESSES
-- =====================================================
CREATE TABLE public.saved_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    address_type TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_saved_addresses_user ON public.saved_addresses(user_id);

-- =====================================================
-- 2. RECENT DESTINATIONS
-- =====================================================
CREATE TABLE public.recent_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    visit_count INTEGER DEFAULT 1,
    last_visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, address)
);

CREATE INDEX idx_recent_destinations_user ON public.recent_destinations(user_id);

-- =====================================================
-- 3. DRIVER MOBILE MONEY
-- =====================================================
CREATE TABLE public.driver_mobile_money (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
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

-- =====================================================
-- 4. EMERGENCY CONTACTS
-- =====================================================
CREATE TABLE public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    relationship TEXT,
    priority_order INTEGER NOT NULL DEFAULT 1,
    notify_via_sms BOOLEAN DEFAULT TRUE,
    notify_via_whatsapp BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, priority_order)
);

CREATE INDEX idx_emergency_contacts_user ON public.emergency_contacts(user_id);

-- =====================================================
-- 5. SOS INCIDENTS
-- =====================================================
CREATE TABLE public.sos_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_role TEXT NOT NULL,
    trip_id UUID,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    location_address TEXT,
    incident_type TEXT DEFAULT 'emergency',
    status TEXT DEFAULT 'active',
    notified_contacts JSONB,
    notified_drivers JSONB,
    responding_users JSONB,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID,
    resolution_notes TEXT,
    device_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sos_incidents_user ON public.sos_incidents(user_id);

-- =====================================================
-- 6. WALLET COMMISSION PAYMENTS
-- =====================================================
CREATE TABLE public.wallet_commission_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL,
    transaction_reference TEXT,
    payment_proof_url TEXT,
    status TEXT DEFAULT 'pending',
    verified_by UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    driver_notes TEXT,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_wallet_commission_payments_driver ON public.wallet_commission_payments(driver_id);

-- =====================================================
-- 7. TRIP PAYMENTS
-- =====================================================
CREATE TABLE public.trip_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    commission_amount NUMERIC(10, 2) NOT NULL,
    driver_net_amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL,
    driver_mobile_money_id UUID REFERENCES public.driver_mobile_money(id) ON DELETE SET NULL,
    driver_phone_number TEXT,
    customer_confirmed BOOLEAN DEFAULT FALSE,
    customer_confirmed_at TIMESTAMP WITH TIME ZONE,
    driver_confirmed BOOLEAN DEFAULT FALSE,
    driver_confirmed_at TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'pending',
    disputed_by TEXT,
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

-- =====================================================
-- POLICIES (SIMPLE - NO TRIPS TABLE REFERENCE)
-- =====================================================

-- Saved Addresses
CREATE POLICY saved_addresses_policy ON public.saved_addresses
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Recent Destinations
CREATE POLICY recent_destinations_policy ON public.recent_destinations
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Driver Mobile Money - SIMPLE (no trips reference)
CREATE POLICY driver_mobile_money_owner_policy ON public.driver_mobile_money
    FOR ALL USING (driver_id = auth.uid()) WITH CHECK (driver_id = auth.uid());

-- Emergency Contacts
CREATE POLICY emergency_contacts_policy ON public.emergency_contacts
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- SOS Incidents
CREATE POLICY sos_incidents_policy ON public.sos_incidents
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Wallet Commission Payments
CREATE POLICY wallet_commission_payments_policy ON public.wallet_commission_payments
    FOR ALL USING (driver_id = auth.uid()) WITH CHECK (driver_id = auth.uid());

-- Trip Payments
CREATE POLICY trip_payments_policy ON public.trip_payments
    FOR ALL USING (customer_id = auth.uid() OR driver_id = auth.uid())
    WITH CHECK (customer_id = auth.uid() OR driver_id = auth.uid());

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Update timestamp function
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        CREATE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
    END IF;
END $$;

-- Upsert recent destination
CREATE FUNCTION upsert_recent_destination(
    p_user_id UUID,
    p_address TEXT,
    p_latitude NUMERIC,
    p_longitude NUMERIC
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    UPDATE public.recent_destinations
    SET visit_count = visit_count + 1, last_visited_at = NOW()
    WHERE user_id = p_user_id AND address = p_address
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        INSERT INTO public.recent_destinations (user_id, address, latitude, longitude)
        VALUES (p_user_id, p_address, p_latitude, p_longitude)
        RETURNING id INTO v_id;
    END IF;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure single primary mobile money
CREATE FUNCTION ensure_single_primary_mobile_money()
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

-- =====================================================
-- TRIGGERS
-- =====================================================
CREATE TRIGGER trg_saved_addresses_updated BEFORE UPDATE ON public.saved_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_driver_mobile_money_updated BEFORE UPDATE ON public.driver_mobile_money
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_emergency_contacts_updated BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_sos_incidents_updated BEFORE UPDATE ON public.sos_incidents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_wallet_commission_updated BEFORE UPDATE ON public.wallet_commission_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_trip_payments_updated BEFORE UPDATE ON public.trip_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_single_primary_mobile_money BEFORE INSERT OR UPDATE ON public.driver_mobile_money
    FOR EACH ROW WHEN (NEW.is_primary = TRUE)
    EXECUTE FUNCTION ensure_single_primary_mobile_money();

-- =====================================================
-- SUCCESS! ALL DONE!
-- =====================================================
SELECT 'Migration completed successfully!' as status;
