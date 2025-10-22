-- ============================
-- PAYMENTS INTEGRATION MIGRATION (Week 5)
-- ============================

-- 1. Add commission_amount to trips table
ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS commission_amount numeric DEFAULT 0.0;

-- 2. Add commission and net_amount to payments table
ALTER TABLE public.payments 
ADD COLUMN IF NOT EXISTS commission numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS net_amount numeric DEFAULT 0.0;

-- 3. Create driver_wallets table
CREATE TABLE IF NOT EXISTS public.driver_wallets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  balance numeric NOT NULL DEFAULT 0.0,
  pending_balance numeric NOT NULL DEFAULT 0.0,
  total_earnings numeric NOT NULL DEFAULT 0.0,
  total_commission numeric NOT NULL DEFAULT 0.0,
  last_updated timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT driver_wallets_pkey PRIMARY KEY (id),
  CONSTRAINT driver_wallets_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id),
  CONSTRAINT driver_wallets_driver_id_unique UNIQUE (driver_id)
);

-- 4. Create driver_deposits table
CREATE TABLE IF NOT EXISTS public.driver_deposits (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  amount numeric NOT NULL,
  method varchar NOT NULL CHECK (method IN ('bank', 'mpesa', 'airtelmoney')),
  account_reference varchar NOT NULL,
  proof_url text NOT NULL,
  status varchar NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz DEFAULT now(),
  approved_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,
  CONSTRAINT driver_deposits_pkey PRIMARY KEY (id),
  CONSTRAINT driver_deposits_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id)
);

-- 5. Add payload JSONB column to notifications table
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS payload JSONB;

-- 6. Enable RLS on new tables
ALTER TABLE public.driver_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_deposits ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies for driver_wallets
CREATE POLICY "Drivers can view own wallet" ON public.driver_wallets 
FOR SELECT USING (auth.uid() = driver_id);

CREATE POLICY "Service role can update wallets" ON public.driver_wallets 
FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- 8. RLS Policies for driver_deposits
CREATE POLICY "Drivers can view own deposits" ON public.driver_deposits 
FOR SELECT USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can create own deposits" ON public.driver_deposits 
FOR INSERT WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Service role can manage deposits" ON public.driver_deposits 
FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- 9. Create RPC function: complete_trip_with_cash
CREATE OR REPLACE FUNCTION public.complete_trip_with_cash(p_trip_id uuid)
RETURNS TABLE(
  trip_id uuid,
  driver_id uuid,
  final_price numeric,
  commission_amount numeric,
  net_earnings numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip_record RECORD;
  v_commission_rate numeric := 0.15; -- 15% commission
  v_commission_amount numeric;
  v_net_earnings numeric;
BEGIN
  -- Get trip details
  SELECT * INTO v_trip_record 
  FROM trips 
  WHERE id = p_trip_id AND status = 'in_progress';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trip not found or not in progress';
  END IF;
  
  -- Calculate commission and net earnings
  v_commission_amount := v_trip_record.final_price * v_commission_rate;
  v_net_earnings := v_trip_record.final_price - v_commission_amount;
  
  -- Update trip with commission
  UPDATE trips 
  SET 
    status = 'completed',
    end_time = now(),
    commission_amount = v_commission_amount,
    updated_at = now()
  WHERE id = p_trip_id;
  
  -- Create payment record
  INSERT INTO payments (
    ride_id,
    customer_id,
    driver_id,
    amount,
    payment_method,
    status,
    commission,
    net_amount,
    processed_at
  )
  SELECT 
    NULL, -- ride_id not available in trips table
    v_trip_record.rider_id,
    v_trip_record.driver_id,
    v_trip_record.final_price,
    'cash',
    'completed',
    v_commission_amount,
    v_net_earnings,
    now()
  FROM trips t
  WHERE t.id = p_trip_id;
  
  -- Update or create driver wallet
  INSERT INTO driver_wallets (driver_id, balance, total_earnings, total_commission)
  VALUES (
    v_trip_record.driver_id,
    v_net_earnings,
    v_trip_record.final_price,
    v_commission_amount
  )
  ON CONFLICT (driver_id) 
  DO UPDATE SET
    balance = driver_wallets.balance + EXCLUDED.balance,
    total_earnings = driver_wallets.total_earnings + EXCLUDED.total_earnings,
    total_commission = driver_wallets.total_commission + EXCLUDED.total_commission,
    last_updated = now(),
    updated_at = now();
  
  -- Create notification for driver
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    payload,
    trip_id
  )
  VALUES (
    v_trip_record.driver_id,
    'Trip Completed',
    'Your trip has been completed. Earnings: $' || v_net_earnings,
    'payment',
    jsonb_build_object(
      'trip_id', p_trip_id,
      'earnings', v_net_earnings,
      'commission', v_commission_amount
    ),
    p_trip_id
  );
  
  -- Return trip details with commission
  RETURN QUERY
  SELECT 
    p_trip_id,
    v_trip_record.driver_id,
    v_trip_record.final_price,
    v_commission_amount,
    v_net_earnings;
END;
$$;

-- 10. Create RPC function: approve_driver_deposit
CREATE OR REPLACE FUNCTION public.approve_driver_deposit(p_deposit_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deposit_record RECORD;
BEGIN
  -- Get deposit details
  SELECT * INTO v_deposit_record 
  FROM driver_deposits 
  WHERE id = p_deposit_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deposit not found or not pending';
  END IF;
  
  -- Update deposit status
  UPDATE driver_deposits 
  SET 
    status = 'approved',
    approved_at = now(),
    updated_at = now()
  WHERE id = p_deposit_id;
  
  -- Update driver wallet
  INSERT INTO driver_wallets (driver_id, balance, pending_balance)
  VALUES (
    v_deposit_record.driver_id,
    v_deposit_record.amount,
    0
  )
  ON CONFLICT (driver_id) 
  DO UPDATE SET
    balance = driver_wallets.balance + v_deposit_record.amount,
    pending_balance = driver_wallets.pending_balance - v_deposit_record.amount,
    last_updated = now(),
    updated_at = now();
  
  -- Create notification for driver
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    payload
  )
  VALUES (
    v_deposit_record.driver_id,
    'Deposit Approved',
    'Your deposit of $' || v_deposit_record.amount || ' has been approved',
    'payment',
    jsonb_build_object(
      'deposit_id', p_deposit_id,
      'amount', v_deposit_record.amount,
      'method', v_deposit_record.method
    )
  );
END;
$$;

-- 11. Create RPC function: reject_driver_deposit
CREATE OR REPLACE FUNCTION public.reject_driver_deposit(
  p_deposit_id uuid,
  p_rejection_reason text DEFAULT 'Rejected by administrator'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deposit_record RECORD;
BEGIN
  -- Get deposit details
  SELECT * INTO v_deposit_record 
  FROM driver_deposits 
  WHERE id = p_deposit_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deposit not found or not pending';
  END IF;
  
  -- Update deposit status
  UPDATE driver_deposits 
  SET 
    status = 'rejected',
    rejected_at = now(),
    rejection_reason = p_rejection_reason,
    updated_at = now()
  WHERE id = p_deposit_id;
  
  -- Create notification for driver
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    payload
  )
  VALUES (
    v_deposit_record.driver_id,
    'Deposit Rejected',
    'Your deposit of $' || v_deposit_record.amount || ' was rejected: ' || p_rejection_reason,
    'payment',
    jsonb_build_object(
      'deposit_id', p_deposit_id,
      'amount', v_deposit_record.amount,
      'reason', p_rejection_reason
    )
  );
END;
$$;

-- 12. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_driver_wallets_driver_id ON public.driver_wallets(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_deposits_driver_id ON public.driver_deposits(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_deposits_status ON public.driver_deposits(status);
CREATE INDEX IF NOT EXISTS idx_driver_deposits_created_at ON public.driver_deposits(created_at);
CREATE INDEX IF NOT EXISTS idx_payments_commission ON public.payments(commission);
CREATE INDEX IF NOT EXISTS idx_trips_commission_amount ON public.trips(commission_amount);

-- 13. Comments for documentation
COMMENT ON TABLE public.driver_wallets IS 'Driver wallet balances and earnings tracking';
COMMENT ON TABLE public.driver_deposits IS 'Driver deposit submissions and approval workflow';
COMMENT ON COLUMN public.trips.commission_amount IS 'Commission amount deducted from trip earnings';
COMMENT ON COLUMN public.payments.commission IS 'Commission amount for the payment';
COMMENT ON COLUMN public.payments.net_amount IS 'Net amount after commission';
COMMENT ON COLUMN public.notifications.payload IS 'Additional data for notifications in JSON format';

-- 14. Insert initial wallet records for existing drivers
INSERT INTO public.driver_wallets (driver_id, balance, total_earnings, total_commission)
SELECT 
  d.id,
  0.0,
  0.0,
  0.0
FROM public.drivers d
WHERE NOT EXISTS (
  SELECT 1 FROM public.driver_wallets dw WHERE dw.driver_id = d.id
);

-- ============================
-- MIGRATION COMPLETE
-- ============================