-- migration_v10_recovery_sync.sql
-- Recovery Sync Patch v10: adds missing columns, RLS, functions, triggers, and verification helpers
-- Idempotent where practical: DROP IF EXISTS, conditional ALTER, DO blocks

SET search_path = public;

-- 0) Ensure telemetry table exists (safe)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relname = 'telemetry_logs' AND n.nspname = 'public') THEN
    CREATE TABLE public.telemetry_logs (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      type text NOT NULL,
      message text NOT NULL,
      meta jsonb DEFAULT '{}'::jsonb,
      timestamp timestamptz DEFAULT now(),
      CONSTRAINT telemetry_logs_pkey PRIMARY KEY (id)
    );
  END IF;
END $$;

-- 1) Add is_approved column to drivers table if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='drivers' AND column_name='is_approved'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN is_approved boolean NOT NULL DEFAULT false;
  END IF;
END $$;

-- 2) Ensure driver_wallets exists with required columns (create if missing)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'driver_wallets') THEN
    CREATE TABLE public.driver_wallets (
      driver_id uuid NOT NULL PRIMARY KEY,
      balance numeric NOT NULL DEFAULT 0.00,
      updated_at timestamptz DEFAULT now()
    );
    -- FK if drivers exists
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname='drivers') THEN
      ALTER TABLE public.driver_wallets
      ADD CONSTRAINT driver_wallets_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- 3) push_notifications and push_delivery_logs safe creation (skip if exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'push_notifications') THEN
    CREATE TABLE public.push_notifications (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      driver_id uuid,
      user_id uuid,
      title text NOT NULL,
      body text NOT NULL,
      data jsonb DEFAULT '{}'::jsonb,
      channel text DEFAULT 'general',
      priority text DEFAULT 'normal',
      status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed')),
      attempts smallint NOT NULL DEFAULT 0,
      last_error text,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      CONSTRAINT push_notifications_pkey PRIMARY KEY (id)
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'push_delivery_logs') THEN
    CREATE TABLE public.push_delivery_logs (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      push_id uuid NOT NULL,
      device_token text,
      status text NOT NULL CHECK (status IN ('delivered','failed','opened','clicked','unknown')),
      details jsonb DEFAULT '{}'::jsonb,
      created_at timestamptz DEFAULT now(),
      CONSTRAINT push_delivery_logs_pkey PRIMARY KEY (id)
    );
    ALTER TABLE public.push_delivery_logs
      ADD CONSTRAINT push_delivery_logs_push_id_fkey FOREIGN KEY (push_id) REFERENCES public.push_notifications(id) ON DELETE CASCADE;
  END IF;
END $$;

-- 4) Driver wallet trigger function: log wallet changes & low-balance push
DROP FUNCTION IF EXISTS public.log_wallet_change(uuid, numeric, numeric) CASCADE;
CREATE FUNCTION public.log_wallet_change(
  p_driver_id uuid,
  p_old_balance numeric,
  p_new_balance numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.telemetry_logs(type, message, meta)
  VALUES ('wallet_change', format('Wallet updated for driver %s: %s -> %s', p_driver_id::text, p_old_balance::text, p_new_balance::text),
          jsonb_build_object('driver_id', p_driver_id, 'old_balance', p_old_balance, 'new_balance', p_new_balance));
END;
$$;

DROP FUNCTION IF EXISTS public.check_and_notify_low_balance(uuid, numeric, numeric) CASCADE;
CREATE FUNCTION public.check_and_notify_low_balance(
  p_driver_id uuid,
  p_old_balance numeric,
  p_new_balance numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  threshold numeric := 50.00;
BEGIN
  IF p_old_balance >= threshold AND p_new_balance < threshold THEN
    INSERT INTO public.push_notifications(driver_id, user_id, title, body, data, channel)
    VALUES (
      p_driver_id, p_driver_id,
      'Low wallet balance',
      format('Your wallet balance is low (R %s). Please deposit to continue receiving rides.', p_new_balance::text),
      jsonb_build_object('type', 'low_balance', 'balance', p_new_balance),
      'wallet'
    );
    INSERT INTO public.telemetry_logs(type, message, meta)
    VALUES ('low_balance_notification', 'Low balance push enqueued', jsonb_build_object('driver_id', p_driver_id, 'balance', p_new_balance));
  END IF;
END;
$$;

-- 5) Create/replace driver_wallets AFTER UPDATE trigger function (safe)
DROP TRIGGER IF EXISTS driver_wallets_after_update ON public.driver_wallets;
DROP FUNCTION IF EXISTS public.driver_wallets_after_update_fn() CASCADE;
CREATE FUNCTION public.driver_wallets_after_update_fn()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.log_wallet_change(NEW.driver_id, OLD.balance, NEW.balance);
  PERFORM public.check_and_notify_low_balance(NEW.driver_id, OLD.balance, NEW.balance);
  RETURN NEW;
END;
$$;
CREATE TRIGGER driver_wallets_after_update
  AFTER UPDATE ON public.driver_wallets
  FOR EACH ROW
  WHEN (OLD.balance IS DISTINCT FROM NEW.balance)
EXECUTE FUNCTION public.driver_wallets_after_update_fn();

-- 6) Add helper RPC to fetch driver dashboard data (idempotent replace)
DROP FUNCTION IF EXISTS public.get_driver_dashboard(uuid) CASCADE;
CREATE FUNCTION public.get_driver_dashboard(p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  w numeric := 0;
  today_earnings numeric := 0;
  weekly_earnings numeric := 0;
  completed_trips int := 0;
  driver_rating numeric := 0;
  recent_trips jsonb := '[]'::jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM public.driver_wallets WHERE driver_id = p_driver_id) THEN
    SELECT balance INTO w FROM public.driver_wallets WHERE driver_id = p_driver_id;
  END IF;

  -- Example earnings: sum driver_earnings for paid/completed
  SELECT COALESCE(SUM(amount),0) INTO today_earnings
  FROM public.driver_earnings
  WHERE driver_id = p_driver_id
    AND created_at::date = now()::date;

  SELECT COALESCE(SUM(amount),0) INTO weekly_earnings
  FROM public.driver_earnings
  WHERE driver_id = p_driver_id
    AND created_at >= (now() - interval '7 days');

  SELECT COALESCE(COUNT(*),0) INTO completed_trips
  FROM public.trips
  WHERE driver_id = p_driver_id AND status = 'completed';

  SELECT d.rating INTO driver_rating FROM public.drivers d WHERE d.id = p_driver_id;

  SELECT jsonb_agg(jsonb_build_object(
    'trip_id', t.id,
    'final_price', t.final_price,
    'status', t.status,
    'created_at', t.created_at
  ))
  INTO recent_trips
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
  ORDER BY t.created_at DESC
  LIMIT 5;

  RETURN jsonb_build_object(
    'driver_id', p_driver_id,
    'wallet_balance', w,
    'today_earnings', today_earnings,
    'weekly_earnings', weekly_earnings,
    'completed_trips', completed_trips,
    'rating', driver_rating,
    'recent_trips', recent_trips
  );
END;
$$;

-- 7) RLS: safe enable & policies for driver_wallets and push_notifications (drop-if-exists)
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_wallets_select_owner ON public.driver_wallets;
CREATE POLICY driver_wallets_select_owner ON public.driver_wallets
  FOR SELECT TO authenticated
  USING (auth.uid() = driver_id);

ALTER TABLE public.push_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_notifications_insert_owner ON public.push_notifications;
DROP POLICY IF EXISTS push_notifications_select_owner ON public.push_notifications;
DROP POLICY IF EXISTS push_notifications_update_owner ON public.push_notifications;

CREATE POLICY push_notifications_insert_owner ON public.push_notifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = driver_id OR auth.role() = 'service_role');

CREATE POLICY push_notifications_select_owner ON public.push_notifications
  FOR SELECT TO authenticated
  USING (auth.uid() = driver_id OR auth.role() = 'service_role');

CREATE POLICY push_notifications_update_owner ON public.push_notifications
  FOR UPDATE TO authenticated
  USING (auth.uid() = driver_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = driver_id OR auth.role() = 'service_role');

-- 8) Helper functions for admin: approve_driver, approve_deposit (idempotent skeletons)
DROP FUNCTION IF EXISTS public.approve_driver(uuid, text) CASCADE;
CREATE FUNCTION public.approve_driver(p_driver_id uuid, p_notes text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.drivers SET is_approved = true, updated_at = now() WHERE id = p_driver_id;
  INSERT INTO public.telemetry_logs(type, message, meta)
  VALUES ('driver_approved', 'Driver approved via DB', jsonb_build_object('driver_id', p_driver_id, 'notes', p_notes));
END;
$$;

DROP FUNCTION IF EXISTS public.approve_driver_deposit(uuid, text) CASCADE;
CREATE FUNCTION public.approve_driver_deposit(p_deposit_id uuid, p_notes text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_driver uuid;
  v_amount numeric;
BEGIN
  SELECT driver_id, amount INTO v_driver, v_amount FROM public.driver_deposits WHERE id = p_deposit_id;
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'deposit not found';
  END IF;
  UPDATE public.driver_deposits SET status = 'approved', reviewed_at = now(), reviewer_notes = p_notes WHERE id = p_deposit_id;
  -- Credit driver wallet
  INSERT INTO public.driver_wallets(driver_id, balance, updated_at)
    VALUES (v_driver, v_amount, now())
  ON CONFLICT (driver_id) DO UPDATE SET balance = public.driver_wallets.balance + EXCLUDED.balance, updated_at = now();
  INSERT INTO public.telemetry_logs(type, message, meta)
  VALUES ('deposit_approved', 'Driver deposit approved', jsonb_build_object('deposit_id', p_deposit_id, 'driver_id', v_driver, 'amount', v_amount));
END;
$$;

-- 9) Indexes for performance (idempotent)
CREATE INDEX IF NOT EXISTS idx_driver_wallets_driver_id ON public.driver_wallets(driver_id);
CREATE INDEX IF NOT EXISTS idx_push_notifications_driver_id ON public.push_notifications(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver_id_created_at ON public.trips(driver_id, created_at);

-- Done