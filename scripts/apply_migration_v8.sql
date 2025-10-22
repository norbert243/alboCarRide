-- Script to apply Migration v8: Realtime Wallet Sync + Push Notifications
-- Copy and paste this entire content into Supabase SQL Editor and run it

-- migration_v8_realtime_wallet_push.sql
-- Realtime wallet sync + push_notifications + telemetry
-- Safe DROP guards included so re-runs are idempotent where possible.

-- 0) Safety: set search_path
SET search_path = public;

-- 1) Create push_notifications table (queue for FCM / worker)
DROP TABLE IF EXISTS push_notifications CASCADE;
CREATE TABLE public.push_notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid,
  user_id uuid,              -- optional: who to send to (driver or rider)
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb,
  channel text DEFAULT 'general',
  priority text DEFAULT 'normal', -- normal / high
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed')),
  attempts smallint NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT push_notifications_pkey PRIMARY KEY (id)
);

-- 2) Add updated_at trigger helper if not exists
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Attach to push_notifications
DROP TRIGGER IF EXISTS push_notifications_update_updated_at ON public.push_notifications;
CREATE TRIGGER push_notifications_update_updated_at
  BEFORE UPDATE ON public.push_notifications
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3) Telemetry table already exists; ensure column consistency
-- (telemetry_logs assumed present per prior migrations)
-- If telemetry_logs does not exist, create it
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
END;
$$;

-- 4) Function to enqueue push notification
DROP FUNCTION IF EXISTS public.enqueue_push_notification(uuid, uuid, text, text, jsonb, text) CASCADE;
CREATE FUNCTION public.enqueue_push_notification(
  p_driver_id uuid,
  p_user_id uuid,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_channel text DEFAULT 'general'
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  new_id uuid;
BEGIN
  INSERT INTO public.push_notifications (driver_id, user_id, title, body, data, channel)
  VALUES (p_driver_id, p_user_id, p_title, p_body, p_data, p_channel)
  RETURNING id INTO new_id;

  -- Telemetry log
  INSERT INTO public.telemetry_logs (type, message, meta)
  VALUES ('push_enqueued', 'Push enqueued', jsonb_build_object('push_id', new_id, 'driver_id', p_driver_id, 'user_id', p_user_id, 'title', p_title));

  RETURN new_id;
END;
$$;

-- 5) Function to log wallet change telemetry
DROP FUNCTION IF EXISTS public.log_wallet_change(uuid, numeric, numeric) CASCADE;
CREATE FUNCTION public.log_wallet_change(
  p_driver_id uuid,
  p_old_balance numeric,
  p_new_balance numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.telemetry_logs (type, message, meta)
  VALUES (
    'wallet_change',
    format('Wallet updated for driver %s: %s -> %s', p_driver_id, p_old_balance, p_new_balance),
    jsonb_build_object('driver_id', p_driver_id, 'old_balance', p_old_balance, 'new_balance', p_new_balance)
  );
END;
$$;

-- 6) Low-balance threshold function (can be adjusted)
DROP FUNCTION IF EXISTS public.check_and_notify_low_balance(uuid, numeric, numeric) CASCADE;
CREATE FUNCTION public.check_and_notify_low_balance(
  p_driver_id uuid,
  p_old_balance numeric,
  p_new_balance numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  threshold numeric := 50.00; -- change as needed; match app logic
BEGIN
  -- Only trigger when new_balance crosses below threshold
  IF p_old_balance >= threshold AND p_new_balance < threshold THEN
    PERFORM public.enqueue_push_notification(
      p_driver_id,
      p_driver_id, -- push to driver user (user_id can be driver profile id)
      'Low wallet balance',
      format('Your wallet balance is low (R %s). Please deposit to continue receiving rides.', p_new_balance),
      jsonb_build_object('type','low_balance','balance',p_new_balance),
      'wallet'
    );
  END IF;
END;
$$;

-- 7) DROP trigger and function safely before recreating
DROP TRIGGER IF EXISTS driver_wallets_after_update ON public.driver_wallets;
DROP FUNCTION IF EXISTS public.driver_wallets_after_update_fn() CASCADE;

-- Create the helper function first
CREATE FUNCTION public.driver_wallets_after_update_fn()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- log telemetry
  PERFORM public.log_wallet_change(NEW.driver_id, OLD.balance, NEW.balance);

  -- enqueue low-balance notification if crossing threshold
  PERFORM public.check_and_notify_low_balance(NEW.driver_id, OLD.balance, NEW.balance);

  RETURN NEW;
END;
$$;

-- Then create the trigger that uses it
CREATE TRIGGER driver_wallets_after_update
  AFTER UPDATE ON public.driver_wallets
  FOR EACH ROW
  WHEN (OLD.balance IS DISTINCT FROM NEW.balance)
EXECUTE FUNCTION public.driver_wallets_after_update_fn();

-- 8) Indexes for push_notifications
CREATE INDEX IF NOT EXISTS idx_push_notifications_status ON public.push_notifications(status);
CREATE INDEX IF NOT EXISTS idx_push_notifications_driver_id ON public.push_notifications(driver_id);

-- 9) RLS: enable and add safe policies for push_notifications and driver_wallets telemetry
ALTER TABLE public.push_notifications ENABLE ROW LEVEL SECURITY;
-- Drop policies if exist to avoid duplicate error
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'push_notifications_insert_owner') THEN
    EXECUTE 'ALTER TABLE public.push_notifications DISABLE ROW LEVEL SECURITY';
    -- we will recreate later after enabling
  END IF;
END$$;

-- Remove any specific policies to avoid duplicate creation errors
DROP POLICY IF EXISTS push_notifications_insert_owner ON public.push_notifications;
DROP POLICY IF EXISTS push_notifications_select_owner ON public.push_notifications;
DROP POLICY IF EXISTS push_notifications_update_owner ON public.push_notifications;

-- Allow drivers (authenticated) to insert pushes only for themselves or admin via service role
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

-- Ensure driver_wallets RLS policies exist (safe drop)
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS driver_wallets_select_owner ON public.driver_wallets;
CREATE POLICY driver_wallets_select_owner ON public.driver_wallets
  FOR SELECT TO authenticated
  USING (auth.uid() = driver_id);

-- 10) (Optional) Helper function for workers to mark push as sent/failed
DROP FUNCTION IF EXISTS public.mark_push_sent(uuid, text) CASCADE;
CREATE FUNCTION public.mark_push_sent(p_push_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.push_notifications
  SET status = p_status, attempts = attempts + 1, updated_at = now()
  WHERE id = p_push_id;

  INSERT INTO public.telemetry_logs (type, message, meta)
  VALUES ('push_status_update', 'Push status updated', jsonb_build_object('push_id', p_push_id, 'status', p_status));
END;
$$;

-- Done.