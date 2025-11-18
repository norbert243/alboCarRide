-- Add new columns to ride_requests table
ALTER TABLE public.ride_requests 
ADD COLUMN updated_at timestamp with time zone null default now(),
ADD COLUMN accepted_offer_id uuid null,
ADD COLUMN estimated_distance numeric(8,2) null,
ADD COLUMN estimated_duration integer null,
ADD COLUMN vehicle_type_preference text null,
ADD COLUMN payment_method text null,
ADD COLUMN max_wait_time integer null default 10,
ADD COLUMN special_requirements text null,
ADD COLUMN scheduled_pickup_time timestamp with time zone null,
ADD COLUMN rider_rating_threshold numeric(3,2) null,
ADD COLUMN priority_level text null default 'normal';

-- Add foreign key constraint for accepted_offer_id
ALTER TABLE public.ride_requests 
ADD CONSTRAINT ride_requests_accepted_offer_id_fkey 
FOREIGN KEY (accepted_offer_id) REFERENCES ride_offers(id);

-- Add check constraint for priority_level
ALTER TABLE public.ride_requests 
ADD CONSTRAINT ride_requests_priority_check 
CHECK (priority_level = ANY (ARRAY['low', 'normal', 'high', 'urgent']));

-- Add check constraint for payment_method
ALTER TABLE public.ride_requests 
ADD CONSTRAINT ride_requests_payment_method_check 
CHECK (payment_method = ANY (ARRAY['cash', 'card', 'wallet', 'mobile_money']));

-- Add check constraint for vehicle_type_preference
ALTER TABLE public.ride_requests 
ADD CONSTRAINT ride_requests_vehicle_type_check 
CHECK (vehicle_type_preference = ANY (ARRAY['economy', 'comfort', 'premium', 'xl', 'luxury']));

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_ride_requests_updated_at ON public.ride_requests USING btree (updated_at);
CREATE INDEX IF NOT EXISTS idx_ride_requests_scheduled_time ON public.ride_requests USING btree (scheduled_pickup_time);
CREATE INDEX IF NOT EXISTS idx_ride_requests_priority ON public.ride_requests USING btree (priority_level);
CREATE INDEX IF NOT EXISTS idx_ride_requests_vehicle_type ON public.ride_requests USING btree (vehicle_type_preference);
CREATE INDEX IF NOT EXISTS idx_ride_requests_accepted_offer ON public.ride_requests USING btree (accepted_offer_id);

-- Update the status check constraint to include 'failed' status
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