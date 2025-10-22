-- migration_v10_recovery_auth.sql
-- Idempotent: drop-if-exists guards included
SET search_path = public;

-- 1) ensure profiles table has expected columns (role, verification_status)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='role'
  ) THEN
    ALTER TABLE public.profiles
    ADD COLUMN role varchar DEFAULT 'customer';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='verification_status'
  ) THEN
    ALTER TABLE public.profiles
    ADD COLUMN verification_status text CHECK (verification_status IN ('pending','approved','rejected')) DEFAULT 'pending';
  END IF;
END$$;

-- 2) ensure drivers table exists and has is_approved and created_at columns
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'drivers') THEN
    CREATE TABLE public.drivers (
      id uuid NOT NULL PRIMARY KEY,
      license_number varchar,
      license_expiry date,
      vehicle_make varchar,
      vehicle_model varchar,
      vehicle_year integer,
      vehicle_color varchar,
      license_plate varchar,
      is_online boolean DEFAULT false,
      current_latitude numeric,
      current_longitude numeric,
      rating numeric DEFAULT 0.0,
      total_rides integer DEFAULT 0,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      vehicle_type text CHECK (vehicle_type = ANY (ARRAY['car','motorcycle']))
    );
  END IF;

  -- add is_approved if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='drivers' AND column_name='is_approved'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN is_approved boolean NOT NULL DEFAULT false;
  END IF;

  -- add created_at/updated_at if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='drivers' AND column_name='created_at'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN created_at timestamptz DEFAULT now();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='drivers' AND column_name='updated_at'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END$$;

-- 3) ensure driver_wallets exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'driver_wallets') THEN
    CREATE TABLE public.driver_wallets (
      driver_id uuid NOT NULL PRIMARY KEY REFERENCES public.drivers(id) ON DELETE CASCADE,
      balance numeric NOT NULL DEFAULT 0.00,
      updated_at timestamptz DEFAULT now()
    );
  END IF;
END$$;

-- 4) safe function to upsert profile (server side upsert to avoid duplicate keys)
DROP FUNCTION IF EXISTS public.upsert_profile(uuid, text, text, text) CASCADE;
CREATE FUNCTION public.upsert_profile(
  p_id uuid,
  p_full_name text,
  p_phone text,
  p_role text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role, created_at, updated_at)
  VALUES (p_id, p_full_name, p_phone, p_role, now(), now())
  ON CONFLICT (id)
  DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    updated_at = now();
END;
$$;

-- 5) safe function to create driver record and wallet atomically
DROP FUNCTION IF EXISTS public.create_driver_profile(uuid, text, text, text, text, integer) CASCADE;
CREATE FUNCTION public.create_driver_profile(
  p_driver_id uuid,
  p_vehicle_type text,
  p_vehicle_make text,
  p_vehicle_model text,
  p_license_plate text,
  p_vehicle_year integer
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- ensure drivers record
  INSERT INTO public.drivers (id, vehicle_type, vehicle_make, vehicle_model, license_plate, vehicle_year, created_at, updated_at)
  VALUES (p_driver_id, p_vehicle_type, p_vehicle_make, p_vehicle_model, p_license_plate, p_vehicle_year, now(), now())
  ON CONFLICT (id) DO UPDATE
    SET vehicle_type = EXCLUDED.vehicle_type,
        vehicle_make = EXCLUDED.vehicle_make,
        vehicle_model = EXCLUDED.vehicle_model,
        license_plate = EXCLUDED.license_plate,
        vehicle_year = EXCLUDED.vehicle_year,
        updated_at = now();

  -- create wallet if missing
  INSERT INTO public.driver_wallets (driver_id, balance, updated_at)
  VALUES (p_driver_id, 0.00, now())
  ON CONFLICT (driver_id) DO NOTHING;
END;
$$;

-- 6) create minimal RLS policies for profiles & drivers to allow owner access
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_owner_select ON public.profiles;
CREATE POLICY profiles_owner_select ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS profiles_owner_insert ON public.profiles;
CREATE POLICY profiles_owner_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS drivers_owner_select ON public.drivers;
CREATE POLICY drivers_owner_select ON public.drivers
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS drivers_owner_insert ON public.drivers;
CREATE POLICY drivers_owner_insert ON public.drivers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- 7) helper function to fetch driver dashboard (if missing)
DROP FUNCTION IF EXISTS public.get_driver_dashboard(uuid) CASCADE;
CREATE FUNCTION public.get_driver_dashboard(p_driver_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_balance numeric;
  v_today_earnings numeric;
  v_weekly_earnings numeric;
  v_completed_trips integer;
  v_rating numeric;
  v_recent_trips jsonb;
BEGIN
  SELECT balance INTO v_balance FROM public.driver_wallets WHERE driver_id = p_driver_id;
  SELECT COALESCE(SUM(final_price),0) INTO v_today_earnings
    FROM public.trips t
    WHERE t.driver_id = p_driver_id AND t.created_at::date = now()::date AND t.status = 'completed';

  SELECT COALESCE(SUM(final_price),0) INTO v_weekly_earnings
    FROM public.trips t
    WHERE t.driver_id = p_driver_id AND t.created_at >= (now() - interval '7 days') AND t.status = 'completed';

  SELECT COALESCE(COUNT(*),0) INTO v_completed_trips
    FROM public.trips t
    WHERE t.driver_id = p_driver_id AND t.status = 'completed';

  SELECT COALESCE(AVG(r.rating),0) INTO v_rating
    FROM public.ratings r
    WHERE r.ratee_id = p_driver_id;

  SELECT jsonb_agg(jsonb_build_object(
    'trip_id', t.id,
    'final_price', t.final_price,
    'status', t.status,
    'created_at', t.created_at
  ) ORDER BY t.created_at DESC)
  INTO v_recent_trips
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
  LIMIT 5;

  RETURN jsonb_build_object(
    'balance', v_balance,
    'today_earnings', v_today_earnings,
    'weekly_earnings', v_weekly_earnings,
    'completed_trips', v_completed_trips,
    'rating', v_rating,
    'recent_trips', COALESCE(v_recent_trips, '[]'::jsonb)
  );
END;
$$;

-- Done.