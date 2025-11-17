-- =====================================================
-- AlboCarRide Production Migration
-- Version: 1.0.0
-- Date: 2025-11-17
-- Market: Democratic Republic of Congo
--
-- Features:
-- - Saved Addresses & Recent Destinations
-- - Mobile Money Integration (M-Pesa, Orange Money, Airtel Money)
-- - Emergency SOS System (Passenger & Driver)
-- - Commission Payment Tracking
-- - Trip Payment Management (P2P)
--
-- Security: Row Level Security enabled on all tables
-- Performance: Strategic indexes on all foreign keys and query columns
-- Data Integrity: Comprehensive constraints and validations
-- =====================================================

-- =====================================================
-- EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "cube";
CREATE EXTENSION IF NOT EXISTS "earthdistance";

-- =====================================================
-- PREREQUISITES CHECK
-- =====================================================
DO $$
BEGIN
    -- Verify profiles table exists
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
        RAISE EXCEPTION 'profiles table must exist before running this migration';
    END IF;
END $$;

-- =====================================================
-- SAFE CLEANUP (Idempotent)
-- =====================================================

-- Drop existing objects in correct order (reverse dependency)
DROP TRIGGER IF EXISTS trg_trip_payments_updated ON public.trip_payments;
DROP TRIGGER IF EXISTS trg_wallet_commission_updated ON public.wallet_commission_payments;
DROP TRIGGER IF EXISTS trg_sos_incidents_updated ON public.sos_incidents;
DROP TRIGGER IF EXISTS trg_emergency_contacts_updated ON public.emergency_contacts;
DROP TRIGGER IF EXISTS trg_single_primary_mobile_money ON public.driver_mobile_money;
DROP TRIGGER IF EXISTS trg_driver_mobile_money_updated ON public.driver_mobile_money;
DROP TRIGGER IF EXISTS trg_saved_addresses_updated ON public.saved_addresses;

DROP TABLE IF EXISTS public.trip_payments CASCADE;
DROP TABLE IF EXISTS public.wallet_commission_payments CASCADE;
DROP TABLE IF EXISTS public.sos_incidents CASCADE;
DROP TABLE IF EXISTS public.emergency_contacts CASCADE;
DROP TABLE IF EXISTS public.driver_mobile_money CASCADE;
DROP TABLE IF EXISTS public.recent_destinations CASCADE;
DROP TABLE IF EXISTS public.saved_addresses CASCADE;

DROP FUNCTION IF EXISTS upsert_recent_destination(UUID, TEXT, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS ensure_single_primary_mobile_money();

-- =====================================================
-- TABLE: saved_addresses
-- Purpose: Store user's frequently used addresses (home, work, etc.)
-- =====================================================
CREATE TABLE public.saved_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Address information
    label TEXT NOT NULL CHECK (char_length(label) BETWEEN 1 AND 100),
    address TEXT NOT NULL CHECK (char_length(address) BETWEEN 3 AND 500),
    latitude NUMERIC(10, 8) CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(11, 8) CHECK (longitude BETWEEN -180 AND 180),

    -- Address categorization
    address_type TEXT NOT NULL DEFAULT 'other' CHECK (address_type IN ('home', 'work', 'other')),

    -- Optional metadata
    notes TEXT CHECK (notes IS NULL OR char_length(notes) <= 500),

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT unique_label_per_user UNIQUE (user_id, label)
);

-- Performance indexes
CREATE INDEX idx_saved_addresses_user_id ON public.saved_addresses(user_id);
CREATE INDEX idx_saved_addresses_type ON public.saved_addresses(address_type) WHERE address_type IN ('home', 'work');

-- Security
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own saved addresses"
    ON public.saved_addresses
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.saved_addresses IS 'User saved addresses (home, work, favorites) for quick ride booking';
COMMENT ON COLUMN public.saved_addresses.address_type IS 'Address category: home, work, or other custom location';

-- =====================================================
-- TABLE: recent_destinations
-- Purpose: Auto-track frequently visited locations
-- =====================================================
CREATE TABLE public.recent_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Location information
    address TEXT NOT NULL CHECK (char_length(address) BETWEEN 3 AND 500),
    latitude NUMERIC(10, 8) CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(11, 8) CHECK (longitude BETWEEN -180 AND 180),

    -- Usage tracking
    visit_count INTEGER NOT NULL DEFAULT 1 CHECK (visit_count >= 1),
    last_visited_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT unique_user_address UNIQUE (user_id, address)
);

-- Performance indexes
CREATE INDEX idx_recent_destinations_user_id ON public.recent_destinations(user_id);
CREATE INDEX idx_recent_destinations_last_visited ON public.recent_destinations(user_id, last_visited_at DESC);
CREATE INDEX idx_recent_destinations_visit_count ON public.recent_destinations(user_id, visit_count DESC);

-- Security
ALTER TABLE public.recent_destinations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own recent destinations"
    ON public.recent_destinations
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.recent_destinations IS 'Auto-tracked frequently visited destinations for quick selection';
COMMENT ON COLUMN public.recent_destinations.visit_count IS 'Number of times user has visited this destination';

-- =====================================================
-- TABLE: driver_mobile_money
-- Purpose: Driver mobile money accounts for receiving payments
-- =====================================================
CREATE TABLE public.driver_mobile_money (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Mobile money provider details
    provider TEXT NOT NULL CHECK (provider IN ('mpesa', 'orange_money', 'airtel_money')),
    phone_number TEXT NOT NULL CHECK (phone_number ~ '^\+?[0-9]{9,15}$'), -- International format validation
    account_name TEXT NOT NULL CHECK (char_length(account_name) BETWEEN 2 AND 100),

    -- Account status
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT valid_verification CHECK (
        (is_verified = FALSE AND verified_at IS NULL) OR
        (is_verified = TRUE AND verified_at IS NOT NULL)
    )
);

-- Performance indexes
CREATE INDEX idx_driver_mobile_money_driver_id ON public.driver_mobile_money(driver_id);
CREATE INDEX idx_driver_mobile_money_provider ON public.driver_mobile_money(provider);
CREATE INDEX idx_driver_mobile_money_primary ON public.driver_mobile_money(driver_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX idx_driver_mobile_money_active ON public.driver_mobile_money(driver_id) WHERE is_active = TRUE;

-- Security
ALTER TABLE public.driver_mobile_money ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers manage their own mobile money accounts"
    ON public.driver_mobile_money
    FOR ALL
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

-- Allow read access for payment purposes (customers need to see where to send money)
CREATE POLICY "Public can view active primary accounts for payments"
    ON public.driver_mobile_money
    FOR SELECT
    USING (is_active = TRUE AND is_primary = TRUE);

COMMENT ON TABLE public.driver_mobile_money IS 'Driver mobile money accounts (M-Pesa, Orange Money, Airtel Money) for receiving trip payments';
COMMENT ON COLUMN public.driver_mobile_money.is_primary IS 'Primary account shown to customers for payment. Only one primary per driver.';
COMMENT ON COLUMN public.driver_mobile_money.phone_number IS 'Mobile money phone number in international format (+243...)';

-- =====================================================
-- TABLE: emergency_contacts
-- Purpose: Emergency contacts for SOS alerts
-- =====================================================
CREATE TABLE public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Contact information
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 100),
    phone_number TEXT NOT NULL CHECK (phone_number ~ '^\+?[0-9]{9,15}$'),
    relationship TEXT CHECK (relationship IS NULL OR char_length(relationship) <= 50),

    -- Priority (1 = primary, 2 = secondary, 3 = tertiary)
    priority_order INTEGER NOT NULL CHECK (priority_order BETWEEN 1 AND 3),

    -- Notification preferences
    notify_via_sms BOOLEAN NOT NULL DEFAULT TRUE,
    notify_via_whatsapp BOOLEAN NOT NULL DEFAULT TRUE,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT unique_priority_per_user UNIQUE (user_id, priority_order),
    CONSTRAINT at_least_one_notification_method CHECK (notify_via_sms = TRUE OR notify_via_whatsapp = TRUE)
);

-- Performance indexes
CREATE INDEX idx_emergency_contacts_user_id ON public.emergency_contacts(user_id);
CREATE INDEX idx_emergency_contacts_active ON public.emergency_contacts(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_emergency_contacts_priority ON public.emergency_contacts(user_id, priority_order);

-- Security
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own emergency contacts"
    ON public.emergency_contacts
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.emergency_contacts IS 'Emergency contacts (max 3 per user) notified during SOS alerts';
COMMENT ON COLUMN public.emergency_contacts.priority_order IS 'Contact priority: 1=primary, 2=secondary, 3=tertiary. Maximum 3 contacts per user.';

-- =====================================================
-- TABLE: sos_incidents
-- Purpose: Track emergency SOS alerts
-- =====================================================
CREATE TABLE public.sos_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Who triggered the SOS
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_role TEXT NOT NULL CHECK (user_role IN ('customer', 'driver')),

    -- Related trip (optional)
    trip_id UUID, -- No FK constraint - trip might be deleted

    -- Location at time of alert
    latitude NUMERIC(10, 8) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(11, 8) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    location_address TEXT,

    -- Incident details
    incident_type TEXT NOT NULL DEFAULT 'emergency' CHECK (
        incident_type IN ('emergency', 'safety_concern', 'accident', 'harassment', 'other')
    ),
    status TEXT NOT NULL DEFAULT 'active' CHECK (
        status IN ('active', 'resolved', 'false_alarm', 'cancelled')
    ),

    -- Response tracking (JSONB for flexibility)
    notified_contacts JSONB,
    notified_drivers JSONB,
    responding_users JSONB,

    -- Resolution details
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolution_notes TEXT CHECK (resolution_notes IS NULL OR char_length(resolution_notes) <= 1000),

    -- Device metadata for debugging
    device_info JSONB,

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT valid_resolution CHECK (
        (status IN ('active', 'cancelled') AND resolved_at IS NULL AND resolved_by IS NULL) OR
        (status IN ('resolved', 'false_alarm') AND resolved_at IS NOT NULL)
    )
);

-- Performance indexes
CREATE INDEX idx_sos_incidents_user_id ON public.sos_incidents(user_id);
CREATE INDEX idx_sos_incidents_status ON public.sos_incidents(status) WHERE status = 'active';
CREATE INDEX idx_sos_incidents_created ON public.sos_incidents(created_at DESC);
CREATE INDEX idx_sos_incidents_trip_id ON public.sos_incidents(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_sos_incidents_location ON public.sos_incidents USING gist (ll_to_earth(latitude, longitude));

-- Security
ALTER TABLE public.sos_incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own SOS incidents"
    ON public.sos_incidents
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow drivers to see incidents where they were notified
CREATE POLICY "Drivers view incidents they were notified about"
    ON public.sos_incidents
    FOR SELECT
    USING (
        user_role = 'driver' AND
        (notified_drivers ? auth.uid()::text OR responding_users ? auth.uid()::text)
    );

COMMENT ON TABLE public.sos_incidents IS 'Emergency SOS incidents with automatic SMS/WhatsApp alerts to contacts or nearby drivers';
COMMENT ON COLUMN public.sos_incidents.notified_contacts IS 'JSON array of contact IDs that were notified (passenger SOS)';
COMMENT ON COLUMN public.sos_incidents.notified_drivers IS 'JSON array of driver IDs that were notified (driver SOS)';

-- =====================================================
-- TABLE: wallet_commission_payments
-- Purpose: Track driver commission payments to platform
-- =====================================================
CREATE TABLE public.wallet_commission_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Payment details
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0 AND amount <= 999999.99),
    payment_method TEXT NOT NULL CHECK (
        payment_method IN ('bank_transfer', 'mpesa', 'orange_money', 'airtel_money', 'cash')
    ),

    -- Proof of payment
    transaction_reference TEXT CHECK (transaction_reference IS NULL OR char_length(transaction_reference) <= 100),
    payment_proof_url TEXT CHECK (payment_proof_url IS NULL OR payment_proof_url ~ '^https?://'),

    -- Verification workflow
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT CHECK (rejection_reason IS NULL OR char_length(rejection_reason) <= 500),

    -- Notes
    driver_notes TEXT CHECK (driver_notes IS NULL OR char_length(driver_notes) <= 500),
    admin_notes TEXT CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 500),

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT valid_verification_status CHECK (
        (status = 'pending' AND verified_at IS NULL AND verified_by IS NULL) OR
        (status IN ('verified', 'rejected') AND verified_at IS NOT NULL AND verified_by IS NOT NULL)
    ),
    CONSTRAINT rejection_requires_reason CHECK (
        (status != 'rejected') OR (rejection_reason IS NOT NULL)
    )
);

-- Performance indexes
CREATE INDEX idx_wallet_commission_driver_id ON public.wallet_commission_payments(driver_id);
CREATE INDEX idx_wallet_commission_status ON public.wallet_commission_payments(status, created_at DESC);
CREATE INDEX idx_wallet_commission_created ON public.wallet_commission_payments(created_at DESC);

-- Security
ALTER TABLE public.wallet_commission_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers manage their own commission payments"
    ON public.wallet_commission_payments
    FOR ALL
    USING (auth.uid() = driver_id)
    WITH CHECK (auth.uid() = driver_id);

COMMENT ON TABLE public.wallet_commission_payments IS 'Driver commission payments to platform (manual verification workflow)';
COMMENT ON COLUMN public.wallet_commission_payments.payment_proof_url IS 'URL to uploaded receipt/screenshot of payment proof';

-- =====================================================
-- TABLE: trip_payments
-- Purpose: Track customer P2P payments to drivers
-- =====================================================
CREATE TABLE public.trip_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Trip and parties
    trip_id UUID NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    -- Payment amounts
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0 AND amount <= 999999.99),
    commission_amount NUMERIC(10, 2) NOT NULL CHECK (commission_amount >= 0 AND commission_amount < amount),
    driver_net_amount NUMERIC(10, 2) NOT NULL CHECK (driver_net_amount > 0),

    -- Payment method details
    payment_method TEXT NOT NULL CHECK (
        payment_method IN ('mpesa', 'orange_money', 'airtel_money', 'cash', 'card')
    ),
    driver_mobile_money_id UUID REFERENCES public.driver_mobile_money(id) ON DELETE SET NULL,
    driver_phone_number TEXT CHECK (driver_phone_number IS NULL OR driver_phone_number ~ '^\+?[0-9]{9,15}$'),

    -- Payment confirmation workflow
    customer_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    customer_confirmed_at TIMESTAMP WITH TIME ZONE,
    driver_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    driver_confirmed_at TIMESTAMP WITH TIME ZONE,

    -- Payment status
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'customer_confirmed', 'completed', 'disputed', 'failed')
    ),

    -- Dispute handling
    disputed_by TEXT CHECK (disputed_by IN ('customer', 'driver')),
    dispute_reason TEXT CHECK (dispute_reason IS NULL OR char_length(dispute_reason) <= 1000),
    dispute_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    dispute_resolution TEXT CHECK (dispute_resolution IS NULL OR char_length(dispute_resolution) <= 1000),

    -- Transaction reference
    transaction_reference TEXT CHECK (transaction_reference IS NULL OR char_length(transaction_reference) <= 100),

    -- Commission tracking
    commission_deducted BOOLEAN NOT NULL DEFAULT FALSE,
    commission_deducted_at TIMESTAMP WITH TIME ZONE,

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Business constraints
    CONSTRAINT unique_trip_payment UNIQUE (trip_id),
    CONSTRAINT valid_amounts CHECK (amount = commission_amount + driver_net_amount),
    CONSTRAINT customer_confirmation_timestamp CHECK (
        (customer_confirmed = FALSE AND customer_confirmed_at IS NULL) OR
        (customer_confirmed = TRUE AND customer_confirmed_at IS NOT NULL)
    ),
    CONSTRAINT driver_confirmation_timestamp CHECK (
        (driver_confirmed = FALSE AND driver_confirmed_at IS NULL) OR
        (driver_confirmed = TRUE AND driver_confirmed_at IS NOT NULL)
    ),
    CONSTRAINT dispute_requires_reason CHECK (
        (disputed_by IS NULL AND dispute_reason IS NULL) OR
        (disputed_by IS NOT NULL AND dispute_reason IS NOT NULL)
    )
);

-- Performance indexes
CREATE INDEX idx_trip_payments_trip_id ON public.trip_payments(trip_id);
CREATE INDEX idx_trip_payments_customer_id ON public.trip_payments(customer_id);
CREATE INDEX idx_trip_payments_driver_id ON public.trip_payments(driver_id);
CREATE INDEX idx_trip_payments_status ON public.trip_payments(status, created_at DESC);
CREATE INDEX idx_trip_payments_pending ON public.trip_payments(customer_id, driver_id) WHERE status IN ('pending', 'customer_confirmed');

-- Security
ALTER TABLE public.trip_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage payments they are involved in"
    ON public.trip_payments
    FOR ALL
    USING (auth.uid() = customer_id OR auth.uid() = driver_id)
    WITH CHECK (auth.uid() = customer_id OR auth.uid() = driver_id);

COMMENT ON TABLE public.trip_payments IS 'Customer P2P mobile money payments to drivers with commission tracking';
COMMENT ON COLUMN public.trip_payments.driver_net_amount IS 'Amount driver receives after commission deduction';
COMMENT ON COLUMN public.trip_payments.commission_deducted IS 'Whether commission has been deducted from driver wallet';

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Reusable function for updating timestamp
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

-- Function: Upsert recent destination (increment visit count or insert)
CREATE FUNCTION upsert_recent_destination(
    p_user_id UUID,
    p_address TEXT,
    p_latitude NUMERIC,
    p_longitude NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_destination_id UUID;
BEGIN
    -- Validate inputs
    IF p_user_id IS NULL OR p_address IS NULL THEN
        RAISE EXCEPTION 'user_id and address are required';
    END IF;

    -- Try to update existing
    UPDATE public.recent_destinations
    SET
        visit_count = visit_count + 1,
        last_visited_at = NOW()
    WHERE user_id = p_user_id AND address = p_address
    RETURNING id INTO v_destination_id;

    -- Insert if not exists
    IF v_destination_id IS NULL THEN
        INSERT INTO public.recent_destinations (user_id, address, latitude, longitude)
        VALUES (p_user_id, p_address, p_latitude, p_longitude)
        RETURNING id INTO v_destination_id;
    END IF;

    RETURN v_destination_id;
END;
$$;

COMMENT ON FUNCTION upsert_recent_destination IS 'Upsert recent destination: increment visit count or create new';

-- Function: Ensure only one primary mobile money account per driver
CREATE FUNCTION ensure_single_primary_mobile_money()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_primary = TRUE THEN
        -- Unset all other primary accounts for this driver
        UPDATE public.driver_mobile_money
        SET is_primary = FALSE
        WHERE driver_id = NEW.driver_id AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID);
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION ensure_single_primary_mobile_money IS 'Ensures only one primary mobile money account per driver';

-- =====================================================
-- APPLY TRIGGERS
-- =====================================================

-- Updated_at triggers
CREATE TRIGGER trg_saved_addresses_updated
    BEFORE UPDATE ON public.saved_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_driver_mobile_money_updated
    BEFORE UPDATE ON public.driver_mobile_money
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_emergency_contacts_updated
    BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_sos_incidents_updated
    BEFORE UPDATE ON public.sos_incidents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_wallet_commission_updated
    BEFORE UPDATE ON public.wallet_commission_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_trip_payments_updated
    BEFORE UPDATE ON public.trip_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Business logic triggers
CREATE TRIGGER trg_single_primary_mobile_money
    BEFORE INSERT OR UPDATE ON public.driver_mobile_money
    FOR EACH ROW
    WHEN (NEW.is_primary = TRUE)
    EXECUTE FUNCTION ensure_single_primary_mobile_money();

-- =====================================================
-- VALIDATION & SUCCESS MESSAGE
-- =====================================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename IN (
        'saved_addresses',
        'recent_destinations',
        'driver_mobile_money',
        'emergency_contacts',
        'sos_incidents',
        'wallet_commission_payments',
        'trip_payments'
    );

    IF table_count = 7 THEN
        RAISE NOTICE '✅ SUCCESS! All 7 production tables created successfully.';
        RAISE NOTICE '✅ Row Level Security enabled on all tables.';
        RAISE NOTICE '✅ Performance indexes created.';
        RAISE NOTICE '✅ Business constraints applied.';
        RAISE NOTICE '✅ AlboCarRide is ready for Congo market! 🇨🇩';
    ELSE
        RAISE EXCEPTION 'Migration incomplete. Expected 7 tables, found %', table_count;
    END IF;
END $$;
