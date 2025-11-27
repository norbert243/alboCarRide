-- Fix RLS policies for ride_requests table
-- This script ensures proper RLS policies for the current schema

-- First, drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Customers can create ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Users can view own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Users can update own ride requests" ON public.ride_requests;
DROP POLICY IF EXISTS "Drivers can view pending requests" ON public.ride_requests;

-- Ensure RLS is enabled
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

-- Customers can create ride requests (INSERT policy)
CREATE POLICY "Customers can create ride requests"
ON public.ride_requests FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid());

-- Users can view their own ride requests (SELECT policy)
CREATE POLICY "Users can view own ride requests"
ON public.ride_requests FOR SELECT
TO authenticated
USING (customer_id = auth.uid());

-- Users can update their own ride requests (UPDATE policy)
CREATE POLICY "Users can update own ride requests"
ON public.ride_requests FOR UPDATE
TO authenticated
USING (customer_id = auth.uid())
WITH CHECK (customer_id = auth.uid());

-- Users can delete their own ride requests (DELETE policy)
CREATE POLICY "Users can delete own ride requests"
ON public.ride_requests FOR DELETE
TO authenticated
USING (customer_id = auth.uid());

-- Drivers can view pending ride requests (SELECT policy for drivers)
CREATE POLICY "Drivers can view pending requests"
ON public.ride_requests FOR SELECT
TO authenticated
USING (
    status = 'pending' AND
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'driver'
    )
);

-- Service role has full access (for admin functions)
CREATE POLICY "Service role full access"
ON public.ride_requests
TO service_role
USING (true)
WITH CHECK (true);

-- Verify the policies are working
COMMENT ON TABLE public.ride_requests IS 'Customer ride requests with RLS policies for security';