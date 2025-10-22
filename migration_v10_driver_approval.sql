-- ===============================================================
--  Migration v10: Driver Approval System + Telemetry Integration
--  Adds driver.is_approved column, logs approval changes,
--  updates RLS and telemetry consistency.
-- ===============================================================

SET search_path = public;

------------------------------------------------------------
-- 1) Add `is_approved` column if it doesn't already exist
------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'drivers'
       AND column_name = 'is_approved'
  ) THEN
    ALTER TABLE public.drivers
      ADD COLUMN is_approved boolean NOT NULL DEFAULT false;
  END IF;
END$$;

------------------------------------------------------------
-- 2) Telemetry helper for approval state changes
------------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_driver_approval_change(uuid, boolean, boolean) CASCADE;
CREATE FUNCTION public.log_driver_approval_change(
  p_driver_id uuid,
  p_old_approved boolean,
  p_new_approved boolean
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.telemetry_logs(type, message, meta)
  VALUES (
    'driver_approval_change',
    format('Driver %s approval state changed: %s → %s',
           p_driver_id, p_old_approved, p_new_approved),
    jsonb_build_object(
      'driver_id', p_driver_id,
      'old_approved', p_old_approved,
      'new_approved', p_new_approved,
      'timestamp', now()
    )
  );
END;
$$;

------------------------------------------------------------
-- 3) Trigger function for logging approval updates
------------------------------------------------------------
DROP FUNCTION IF EXISTS public.driver_approval_after_update_fn() CASCADE;
CREATE FUNCTION public.driver_approval_after_update_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.is_approved IS DISTINCT FROM NEW.is_approved THEN
    PERFORM public.log_driver_approval_change(NEW.id, OLD.is_approved, NEW.is_approved);
  END IF;
  RETURN NEW;
END;
$$;

------------------------------------------------------------
-- 4) Create / replace trigger safely
------------------------------------------------------------
DROP TRIGGER IF EXISTS driver_approval_after_update ON public.drivers;
CREATE TRIGGER driver_approval_after_update
  AFTER UPDATE ON public.drivers
  FOR EACH ROW
  WHEN (OLD.is_approved IS DISTINCT FROM NEW.is_approved)
EXECUTE FUNCTION public.driver_approval_after_update_fn();

------------------------------------------------------------
-- 5) Optional: add composite index for admin dashboards
------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_drivers_is_approved
  ON public.drivers(is_approved);

------------------------------------------------------------
-- 6) RLS Policy Updates (safe re-create)
------------------------------------------------------------
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drivers_select_owner ON public.drivers;
CREATE POLICY drivers_select_owner
  ON public.drivers FOR SELECT TO authenticated
  USING (auth.uid() = id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS drivers_update_owner ON public.drivers;
CREATE POLICY drivers_update_owner
  ON public.drivers FOR UPDATE TO authenticated
  USING (auth.uid() = id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

------------------------------------------------------------
-- 7) Admin helper RPC to toggle approval
------------------------------------------------------------
DROP FUNCTION IF EXISTS public.set_driver_approval(uuid, boolean) CASCADE;
CREATE FUNCTION public.set_driver_approval(
  p_driver_id uuid,
  p_is_approved boolean
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.drivers
     SET is_approved = p_is_approved,
         updated_at = now()
   WHERE id = p_driver_id;

  PERFORM public.log_driver_approval_change(p_driver_id, NULL, p_is_approved);
END;
$$;

-- Done.
-- ===============================================================