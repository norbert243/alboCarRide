-- Fix ride_requests table schema to match app expectations
-- Add customer_id column if it doesn't exist

-- First, check if we need to rename or add the column
DO $$
BEGIN
    -- If there's a rider_id column, rename it to customer_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'rider_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        RENAME COLUMN rider_id TO customer_id;
        RAISE NOTICE 'Renamed rider_id to customer_id';
    END IF;

    -- If there's a user_id column, rename it to customer_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        RENAME COLUMN user_id TO customer_id;
        RAISE NOTICE 'Renamed user_id to customer_id';
    END IF;

    -- If customer_id doesn't exist at all, add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'customer_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added customer_id column';
    END IF;
END $$;

-- Ensure all required columns exist
DO $$
BEGIN
    -- Rename pickup_address to pickup_location if needed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'pickup_address'
        AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'pickup_location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        RENAME COLUMN pickup_address TO pickup_location;
        RAISE NOTICE 'Renamed pickup_address to pickup_location';
    END IF;

    -- Rename dropoff_address to dropoff_location if needed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'dropoff_address'
        AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'dropoff_location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        RENAME COLUMN dropoff_address TO dropoff_location;
        RAISE NOTICE 'Renamed dropoff_address to dropoff_location';
    END IF;

    -- Add pickup_location if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'pickup_location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN pickup_location TEXT;
    END IF;

    -- Add dropoff_location if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'dropoff_location'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN dropoff_location TEXT;
    END IF;

    -- suggested_price
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'suggested_price'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN suggested_price NUMERIC(10, 2);
    END IF;

    -- pickup_latitude
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'pickup_latitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN pickup_latitude DOUBLE PRECISION;
    END IF;

    -- pickup_longitude
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'pickup_longitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN pickup_longitude DOUBLE PRECISION;
    END IF;

    -- dropoff_latitude
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'dropoff_latitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN dropoff_latitude DOUBLE PRECISION;
    END IF;

    -- dropoff_longitude
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'dropoff_longitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN dropoff_longitude DOUBLE PRECISION;
    END IF;

    -- status
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ride_requests'
        AND column_name = 'status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.ride_requests
        ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
END $$;

-- Refresh the schema cache
NOTIFY pgrst, 'reload schema';
