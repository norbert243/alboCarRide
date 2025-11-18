-- Complete Migration for ride_requests table
-- Run this in your Supabase SQL editor

-- 1. Add new columns to ride_requests table
ALTER TABLE public.ride_requests 
ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone null default now(),
ADD COLUMN IF NOT EXISTS accepted_offer_id uuid null,
ADD COLUMN IF NOT EXISTS estimated_distance numeric(8,2) null,
ADD COLUMN IF NOT EXISTS estimated_duration integer null,
ADD COLUMN IF NOT EXISTS vehicle_type_preference text null,
ADD COLUMN IF NOT EXISTS payment_method text null,
ADD COLUMN IF NOT EXISTS max_wait_time integer null default 10,
ADD COLUMN IF NOT EXISTS special_requirements text null,
ADD COLUMN IF NOT EXISTS scheduled_pickup_time timestamp with time zone null,
ADD COLUMN IF NOT EXISTS rider_rating_threshold numeric(3,2) null,
ADD COLUMN IF NOT EXISTS priority_level text null default 'normal';

-- 2. Fix existing column names if needed (in case they were created with wrong names)
DO $$ 
BEGIN
    -- Check if columns exist with wrong names and rename them
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'ride_requests' AND column_name = 'pickup_latitude') THEN
        ALTER TABLE public.ride_requests RENAME COLUMN pickup_latitude TO pickup_lat;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'ride_requests' AND column_name = 'pickup_longitude') THEN
        ALTER TABLE public.ride_requests RENAME COLUMN pickup_longitude TO pickup_lng;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'ride_requests' AND column_name = 'dropoff_latitude') THEN
        ALTER TABLE public.ride_requests RENAME COLUMN dropoff_latitude TO dropoff_lat;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'ride_requests' AND column_name = 'dropoff_longitude') THEN
        ALTER TABLE public.ride_requests RENAME COLUMN dropoff_longitude TO dropoff_lng;
    END IF;
    
    -- Fix any typos like 'titudedropoff_la'
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'ride_requests' AND column_name = 'titudedropoff_la') THEN
        ALTER TABLE public.ride_requests RENAME COLUMN titudedropoff_la TO dropoff_lat;
    END IF;
END $$;

-- 3. Add foreign key constraint for accepted_offer_id
ALTER TABLE public.ride_requests 
ADD CONSTRAINT IF NOT EXISTS ride_requests_accepted_offer_id_fkey 
FOREIGN KEY (accepted_offer_id) REFERENCES ride_offers(id);

-- 4. Add check constraints for enum values
ALTER TABLE public.ride_requests 
ADD CONSTRAINT IF NOT EXISTS ride_requests_priority_check 
CHECK (priority_level = ANY (ARRAY['low', 'normal', 'high', 'urgent']));

ALTER TABLE public.ride_requests 
ADD CONSTRAINT IF NOT EXISTS ride_requests_payment_method_check 
CHECK (payment_method = ANY (ARRAY['cash', 'card', 'wallet', 'mobile_money']));

ALTER TABLE public.ride_requests 
ADD CONSTRAINT IF NOT EXISTS ride_requests_vehicle_type_check 
CHECK (vehicle_type_preference = ANY (ARRAY['economy', 'comfort', 'premium', 'xl', 'luxury']));

-- 5. Update the status check constraint to include 'failed' status
ALTER TABLE public.ride_requests 
DROP CONSTRAINT IF EXISTS ride_requests_status_check;

ALTER TABLE public.ride_requests 
ADD CONSTRAINT ride_requests_status_check 
CHECK (
  (
    status = any (
      array[
        'pending'::text,
        'accepted'::text,
        'cancelled'::text,
        'expired'::text,
        'failed'::text
      ]
    )
  )
);

-- 6. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_ride_requests_updated_at ON public.ride_requests USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_ride_requests_scheduled_time ON public.ride_requests USING btree (scheduled_pickup_time);
CREATE INDEX IF NOT EXISTS idx_ride_requests_priority ON public.ride_requests USING btree (priority_level);
CREATE INDEX IF NOT EXISTS idx_ride_requests_vehicle_type ON public.ride_requests USING btree (vehicle_type_preference);
CREATE INDEX IF NOT EXISTS idx_ride_requests_accepted_offer ON public.ride_requests USING btree (accepted_offer_id);

-- 7. Verify the table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'ride_requests' 
ORDER BY ordinal_position;

-- 8. Optional: Set updated_at for existing records
UPDATE public.ride_requests 
SET updated_at = created_at 
WHERE updated_at IS NULL;

-- Migration completed successfully!