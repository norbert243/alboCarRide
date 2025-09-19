-- Migration: Create driver_documents and ride_offers tables with RLS policies
-- Date: 2025-09-19
-- Description: Adds tables for driver document verification and ride offer negotiations

-- 1) driver_documents table (driver uploads)
CREATE TABLE IF NOT EXISTS public.driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN (
    'license', 'id', 'insurance', 'car_photo', 'plate_photo', 
    'driver_picture', 'moto_photo'
  )),
  file_url TEXT NOT NULL,
  file_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2) ride_offers table (negotiations)
CREATE TABLE IF NOT EXISTS public.ride_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_request_id UUID NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CDF',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON public.driver_documents (driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON public.driver_documents (status);
CREATE INDEX IF NOT EXISTS idx_ride_offers_ride_request_id ON public.ride_offers (ride_request_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver_id ON public.ride_offers (driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_status ON public.ride_offers (status);
CREATE INDEX IF NOT EXISTS idx_ride_offers_expires_at ON public.ride_offers (expires_at);

-- 3) atomic accept RPC function (first-accept-wins)
CREATE OR REPLACE FUNCTION public.accept_offer_atomic(
  p_ride_request UUID,
  p_driver UUID,
  p_amount NUMERIC
)
RETURNS TABLE(success BOOLEAN, message TEXT, trip_id UUID) 
SECURITY DEFINER
AS $$
DECLARE
  _trip UUID;
  _customer_id UUID;
  _base_fare NUMERIC;
BEGIN
  -- Get ride request details and check if it's still open
  SELECT customer_id, estimated_price 
  INTO _customer_id, _base_fare
  FROM public.ride_requests 
  WHERE id = p_ride_request AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'ride_not_found_or_already_taken', NULL::UUID;
    RETURN;
  END IF;
  
  -- Validate amount is within reasonable bounds (70% - 150% of base fare)
  IF p_amount < (_base_fare * 0.7) OR p_amount > (_base_fare * 1.5) THEN
    RETURN QUERY SELECT false, 'amount_out_of_bounds', NULL::UUID;
    RETURN;
  END IF;

  -- Try to secure the ride_request by setting status to 'accepted' only if open
  UPDATE public.ride_requests
  SET status = 'accepted',
      matched_driver_id = p_driver,
      matched_amount = p_amount,
      accepted_at = NOW()
  WHERE id = p_ride_request AND status = 'pending'
  RETURNING id INTO p_ride_request;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'already_taken', NULL::UUID;
    RETURN;
  END IF;

  -- Create a ride record
  INSERT INTO public.rides (
    ride_request_id, 
    customer_id, 
    driver_id, 
    base_fare, 
    total_price,
    status,
    pickup_address,
    pickup_latitude, 
    pickup_longitude,
    dropoff_address,
    dropoff_latitude,
    dropoff_longitude,
    estimated_distance,
    estimated_duration
  )
  SELECT 
    rr.id,
    rr.customer_id,
    p_driver,
    p_amount,
    p_amount,
    'driver_assigned',
    rr.pickup_address,
    rr.pickup_latitude,
    rr.pickup_longitude,
    rr.dropoff_address,
    rr.dropoff_latitude,
    rr.dropoff_longitude,
    rr.estimated_distance,
    rr.estimated_duration
  FROM public.ride_requests rr
  WHERE rr.id = p_ride_request
  RETURNING id INTO _trip;

  -- Update ride offer status to accepted
  UPDATE public.ride_offers
  SET status = 'accepted',
      updated_at = NOW()
  WHERE ride_request_id = p_ride_request 
    AND driver_id = p_driver
    AND status = 'pending';

  -- Return success and trip id
  RETURN QUERY SELECT true, 'matched', _trip;
END;
$$ LANGUAGE plpgsql;

-- 4) RLS Policies for driver_documents
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;

-- Allow drivers to insert their own documents
CREATE POLICY driver_documents_insert ON public.driver_documents
  FOR INSERT WITH CHECK (auth.uid()::UUID = driver_id);

-- Allow drivers to read their own documents
CREATE POLICY driver_documents_select ON public.driver_documents
  FOR SELECT USING (auth.uid()::UUID = driver_id);

-- Allow admin role to read all documents
CREATE POLICY driver_documents_admin_select ON public.driver_documents
  FOR SELECT USING (auth.jwt() ->> 'role' = 'service_role');

-- Allow admin role to update document status
CREATE POLICY driver_documents_admin_update ON public.driver_documents
  FOR UPDATE USING (auth.jwt() ->> 'role' = 'service_role');

-- 5) RLS Policies for ride_offers
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;

-- Allow drivers to insert their own offers
CREATE POLICY ride_offers_driver_insert ON public.ride_offers
  FOR INSERT WITH CHECK (auth.uid()::UUID = driver_id);

-- Allow drivers to read their own offers
CREATE POLICY ride_offers_driver_select ON public.ride_offers
  FOR SELECT USING (auth.uid()::UUID = driver_id);

-- Allow customers to read offers for their ride requests
CREATE POLICY ride_offers_customer_select ON public.ride_offers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.ride_requests rr 
      WHERE rr.id = ride_request_id AND rr.customer_id = auth.uid()::UUID
    )
  );

-- Allow admin role to read all offers
CREATE POLICY ride_offers_admin_select ON public.ride_offers
  FOR SELECT USING (auth.jwt() ->> 'role' = 'service_role');

-- 6) Update triggers for new tables
CREATE TRIGGER update_driver_documents_updated_at BEFORE UPDATE ON public.driver_documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ride_offers_updated_at BEFORE UPDATE ON public.ride_offers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7) Add is_verified column to profiles table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'is_verified'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

-- 8) Add last_online_at column to drivers table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'drivers' AND column_name = 'last_online_at'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN last_online_at TIMESTAMP WITH TIME ZONE;
  END IF;
END $$;

-- 9) Add matched_driver_id and matched_amount columns to ride_requests if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ride_requests' AND column_name = 'matched_driver_id'
  ) THEN
    ALTER TABLE public.ride_requests ADD COLUMN matched_driver_id UUID REFERENCES public.profiles(id);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ride_requests' AND column_name = 'matched_amount'
  ) THEN
    ALTER TABLE public.ride_requests ADD COLUMN matched_amount NUMERIC(10,2);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ride_requests' AND column_name = 'accepted_at'
  ) THEN
    ALTER TABLE public.ride_requests ADD COLUMN accepted_at TIMESTAMP WITH TIME ZONE;
  END IF;
END $$;

-- Migration completed
COMMENT ON TABLE public.driver_documents IS 'Stores driver verification documents for approval process';
COMMENT ON TABLE public.ride_offers IS 'Stores ride offers and counteroffers during negotiation phase';