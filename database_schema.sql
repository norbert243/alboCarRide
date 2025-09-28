-- ============================
-- PROFILES & USERS
-- ============================

CREATE TABLE public.users (
  id uuid NOT NULL,
  email varchar NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name varchar NOT NULL,
  phone varchar,
  role varchar NOT NULL CHECK (role IN ('customer','driver')),
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  car_model text,
  license_plate text,
  is_online boolean DEFAULT false,
  rating numeric DEFAULT 5.0,
  total_ratings int DEFAULT 0,
  verification_status text CHECK (verification_status IN ('pending','approved','rejected')),
  verification_submitted_at timestamptz,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- ============================
-- CUSTOMERS & DRIVERS
-- ============================

CREATE TABLE public.customers (
  id uuid NOT NULL,
  preferred_payment_method varchar DEFAULT 'cash',
  rating numeric DEFAULT 0.0,
  total_rides int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (id)
);

CREATE TABLE public.drivers (
  id uuid NOT NULL,
  license_number varchar,
  license_expiry date,
  vehicle_make varchar,
  vehicle_model varchar,
  vehicle_year int,
  vehicle_color varchar,
  license_plate varchar,
  is_online boolean DEFAULT false,
  current_latitude numeric,
  current_longitude numeric,
  rating numeric DEFAULT 0.0,
  total_rides int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  vehicle_type text CHECK (vehicle_type IN ('car','motorcycle')),
  CONSTRAINT drivers_pkey PRIMARY KEY (id)
);

-- ============================
-- DRIVER DOCUMENTS & LOCATIONS
-- ============================

CREATE TABLE public.driver_documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  document_type varchar NOT NULL CHECK (
    document_type IN (
      'driver_license','id_card','insurance',
      'vehicle_photo','plate_photo','driver_photo'
    )
  ),
  document_url text NOT NULL,
  status varchar DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  rejection_reason text,
  uploaded_at timestamptz DEFAULT now(),
  reviewed_at timestamptz,
  reviewer_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT driver_documents_pkey PRIMARY KEY (id),
  CONSTRAINT driver_documents_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id)
);

CREATE TABLE public.driver_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  updated_at timestamp DEFAULT now(),
  speed numeric,
  accuracy numeric,
  CONSTRAINT driver_locations_pkey PRIMARY KEY (id),
  CONSTRAINT driver_locations_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id)
);

-- ============================
-- RIDE REQUESTS & OFFERS
-- ============================

CREATE TABLE public.ride_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  rider_id uuid NOT NULL,
  pickup_address text NOT NULL,
  dropoff_address text NOT NULL,
  proposed_price numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','cancelled','expired')),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '15 minutes'),
  notes text,
  CONSTRAINT ride_requests_pkey PRIMARY KEY (id),
  CONSTRAINT ride_requests_rider_id_fkey FOREIGN KEY (rider_id) REFERENCES public.profiles(id)
);

CREATE TABLE public.ride_offers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL,
  request_id uuid NOT NULL,
  offer_price numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','cancelled')),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '10 minutes'),
  CONSTRAINT ride_offers_pkey PRIMARY KEY (id),
  CONSTRAINT ride_offers_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.profiles(id),
  CONSTRAINT ride_offers_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ride_requests(id)
);

-- ============================
-- RIDES & TRIPS
-- ============================

CREATE TABLE public.rides (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ride_request_id uuid,
  customer_id uuid,
  driver_id uuid,
  pickup_address text NOT NULL,
  pickup_latitude numeric NOT NULL,
  pickup_longitude numeric NOT NULL,
  dropoff_address text NOT NULL,
  dropoff_latitude numeric NOT NULL,
  dropoff_longitude numeric NOT NULL,
  actual_distance numeric,
  actual_duration int,
  base_fare numeric NOT NULL,
  distance_fare numeric,
  time_fare numeric,
  surge_multiplier numeric DEFAULT 1.0,
  total_price numeric NOT NULL,
  status varchar NOT NULL CHECK (status IN ('scheduled','picked_up','in_progress','completed','cancelled')),
  scheduled_for timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  customer_rating int CHECK (customer_rating BETWEEN 1 AND 5),
  driver_rating int CHECK (driver_rating BETWEEN 1 AND 5),
  customer_feedback text,
  driver_feedback text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT rides_pkey PRIMARY KEY (id),
  CONSTRAINT rides_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT rides_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id)
);

CREATE TABLE public.trips (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  rider_id uuid NOT NULL,
  driver_id uuid NOT NULL,
  request_id uuid NOT NULL,
  offer_id uuid NOT NULL,
  start_time timestamptz,
  end_time timestamptz,
  final_price numeric,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  cancellation_reason text,
  CONSTRAINT trips_pkey PRIMARY KEY (id),
  CONSTRAINT trips_rider_id_fkey FOREIGN KEY (rider_id) REFERENCES public.profiles(id),
  CONSTRAINT trips_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.profiles(id),
  CONSTRAINT trips_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ride_requests(id),
  CONSTRAINT trips_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.ride_offers(id)
);

-- ============================
-- PAYMENTS & EARNINGS
-- ============================

CREATE TABLE public.payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ride_id uuid,
  customer_id uuid,
  driver_id uuid,
  amount numeric NOT NULL,
  payment_method varchar NOT NULL CHECK (payment_method IN ('cash','card','mobile_money')),
  status varchar NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','failed','refunded')),
  transaction_id varchar,
  processed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id),
  CONSTRAINT payments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT payments_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id)
);

CREATE TABLE public.driver_earnings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  driver_id uuid,
  ride_id uuid,
  amount numeric NOT NULL,
  commission numeric NOT NULL,
  net_earnings numeric NOT NULL,
  payment_status varchar NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','processing')),
  paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT driver_earnings_pkey PRIMARY KEY (id),
  CONSTRAINT driver_earnings_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(id),
  CONSTRAINT driver_earnings_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id)
);

-- ============================
-- LOCATIONS & RATINGS
-- ============================

CREATE TABLE public.ride_locations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  ride_id uuid,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  speed numeric,
  heading numeric,
  accuracy numeric,
  recorded_at timestamptz DEFAULT now(),
  CONSTRAINT ride_locations_pkey PRIMARY KEY (id),
  CONSTRAINT ride_locations_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id)
);

CREATE TABLE public.ratings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL,
  rater_id uuid NOT NULL,
  ratee_id uuid NOT NULL,
  rating int NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT ratings_pkey PRIMARY KEY (id),
  CONSTRAINT ratings_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(id),
  CONSTRAINT ratings_rater_id_fkey FOREIGN KEY (rater_id) REFERENCES public.profiles(id),
  CONSTRAINT ratings_ratee_id_fkey FOREIGN KEY (ratee_id) REFERENCES public.profiles(id)
);

-- ============================
-- NOTIFICATIONS
-- ============================

CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  title varchar NOT NULL,
  message text NOT NULL,
  type varchar NOT NULL CHECK (type IN ('ride_update','payment','promotion','system','verification')),
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  ride_id uuid,
  trip_id uuid,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT notifications_ride_id_fkey FOREIGN KEY (ride_id) REFERENCES public.rides(id),
  CONSTRAINT notifications_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(id)
);

-- ============================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles RLS Policies
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Driver Documents RLS Policies
CREATE POLICY "Drivers can view own documents" ON public.driver_documents FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can upload own documents" ON public.driver_documents FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers can update own documents" ON public.driver_documents FOR UPDATE USING (auth.uid() = driver_id);

-- Ride Requests RLS Policies
CREATE POLICY "Users can view own ride requests" ON public.ride_requests FOR SELECT USING (auth.uid() = rider_id);
CREATE POLICY "Users can create ride requests" ON public.ride_requests FOR INSERT WITH CHECK (auth.uid() = rider_id);
CREATE POLICY "Users can update own ride requests" ON public.ride_requests FOR UPDATE USING (auth.uid() = rider_id);

-- Notifications RLS Policies
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- ============================
-- STORAGE BUCKET CONFIGURATION
-- ============================

-- Create storage bucket for driver documents (if not exists)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('driver-documents', 'driver-documents', false)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for storage bucket
CREATE POLICY "Drivers can upload own documents" ON storage.objects 
FOR INSERT WITH CHECK (bucket_id = 'driver-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Drivers can view own documents" ON storage.objects 
FOR SELECT USING (bucket_id = 'driver-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Drivers can update own documents" ON storage.objects 
FOR UPDATE USING (bucket_id = 'driver-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Drivers can delete own documents" ON storage.objects 
FOR DELETE USING (bucket_id = 'driver-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================
-- INDEXES FOR PERFORMANCE
-- ============================

-- Profiles indexes
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_verification_status ON public.profiles(verification_status);

-- Drivers indexes
CREATE INDEX idx_drivers_online_status ON public.drivers(is_online);
CREATE INDEX idx_drivers_vehicle_type ON public.drivers(vehicle_type);

-- Ride requests indexes
CREATE INDEX idx_ride_requests_status ON public.ride_requests(status);
CREATE INDEX idx_ride_requests_expires_at ON public.ride_requests(expires_at);

-- Rides indexes
CREATE INDEX idx_rides_status ON public.rides(status);
CREATE INDEX idx_rides_customer_id ON public.rides(customer_id);
CREATE INDEX idx_rides_driver_id ON public.rides(driver_id);

-- Driver locations indexes
CREATE INDEX idx_driver_locations_driver_id ON public.driver_locations(driver_id);
CREATE INDEX idx_driver_locations_updated_at ON public.driver_locations(updated_at);

-- Notifications indexes
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);

-- ============================
-- COMMENTS FOR DOCUMENTATION
-- ============================

COMMENT ON TABLE public.profiles IS 'User profiles with role-based access control';
COMMENT ON TABLE public.drivers IS 'Driver-specific information and vehicle details';
COMMENT ON TABLE public.driver_documents IS 'Driver verification documents and status';
COMMENT ON TABLE public.ride_requests IS 'Customer ride requests with pricing and status';
COMMENT ON TABLE public.rides IS 'Completed and active rides with detailed tracking';
COMMENT ON TABLE public.payments IS 'Payment transactions for completed rides';
COMMENT ON TABLE public.notifications IS 'User notifications for ride updates and system messages';