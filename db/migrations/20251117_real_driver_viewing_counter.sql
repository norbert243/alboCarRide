-- Create table to track when drivers view ride requests
-- This enables real driver viewing counter (not fake random numbers)

-- Create ride_request_views table
CREATE TABLE IF NOT EXISTS public.ride_request_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_request_id UUID NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(ride_request_id, driver_id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_ride_request_views_request_id
  ON public.ride_request_views(ride_request_id);

CREATE INDEX IF NOT EXISTS idx_ride_request_views_driver_id
  ON public.ride_request_views(driver_id);

-- Enable RLS
ALTER TABLE public.ride_request_views ENABLE ROW LEVEL SECURITY;

-- Policy: Drivers can insert their own views
CREATE POLICY "Drivers can record their views"
  ON public.ride_request_views
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = driver_id);

-- Policy: Anyone can read views (for counting)
CREATE POLICY "Anyone can read views"
  ON public.ride_request_views
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Drivers can update their own views
CREATE POLICY "Drivers can update their views"
  ON public.ride_request_views
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
