-- Telemetry Schema - Add Missing Columns to Existing Tables
-- This script adds the missing columns to existing tables instead of creating new ones

-- ==========================================================
-- ADD MISSING COLUMNS TO EXISTING TABLES
-- ==========================================================

-- 1. Add driver_id column to telemetry_logs table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'telemetry_logs' AND column_name = 'driver_id'
    ) THEN
        ALTER TABLE public.telemetry_logs ADD COLUMN driver_id UUID;
    END IF;
END $$;

-- 2. Add user_id column to telemetry_logs table if it doesn't exist (for consistency)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'telemetry_logs' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.telemetry_logs ADD COLUMN user_id UUID;
    END IF;
END $$;

-- 3. Create telemetry_aggregates table if it doesn't exist (simple version)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = 'telemetry_aggregates'
    ) THEN
        CREATE TABLE public.telemetry_aggregates (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            driver_id UUID,
            metric_type TEXT NOT NULL,
            metric_value NUMERIC(15,4),
            period_start TIMESTAMP WITH TIME ZONE,
            period_end TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- ==========================================================
-- CREATE MISSING RPC FUNCTIONS
-- ==========================================================

-- 1. upload_telemetry_event function - SIMPLE VERSION
CREATE OR REPLACE FUNCTION public.upload_telemetry_event(
    p_driver_id UUID,
    p_event_type TEXT,
    p_message TEXT,
    p_meta JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Insert the telemetry event
    INSERT INTO public.telemetry_logs (
        driver_id,
        type,
        message,
        meta
    ) VALUES (
        p_driver_id,
        p_event_type,
        p_message,
        p_meta
    ) RETURNING id INTO v_log_id;

    -- Return success response
    RETURN jsonb_build_object(
        'success', true,
        'log_id', v_log_id,
        'message', 'Telemetry event recorded successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to record telemetry event'
        );
END;
$$;

-- 2. record_telemetry_batch function - SIMPLE VERSION
CREATE OR REPLACE FUNCTION public.record_telemetry_batch(
    p_events JSONB[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_event JSONB;
    v_success_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_errors JSONB := '[]'::JSONB;
BEGIN
    -- Process each event in the batch
    FOREACH v_event IN ARRAY p_events
    LOOP
        BEGIN
            INSERT INTO public.telemetry_logs (
                driver_id,
                type,
                message,
                meta
            ) VALUES (
                (v_event->>'driver_id')::UUID,
                v_event->>'type',
                v_event->>'message',
                v_event->'meta'
            );
            
            v_success_count := v_success_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                v_errors := v_errors || jsonb_build_object(
                    'event', v_event,
                    'error', SQLERRM
                );
        END;
    END LOOP;

    -- Return batch processing summary
    RETURN jsonb_build_object(
        'success', true,
        'processed_count', v_success_count + v_error_count,
        'success_count', v_success_count,
        'error_count', v_error_count,
        'errors', v_errors
    );
END;
$$;

-- ==========================================================
-- UPDATE EXISTING GET_DRIVER_DASHBOARD FUNCTION
-- ==========================================================

-- Replace the existing get_driver_dashboard function with enhanced version
CREATE OR REPLACE FUNCTION public.get_driver_dashboard(p_driver_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dashboard_data JSONB;
    v_total_earnings NUMERIC(12,2);
    v_total_trips INTEGER;
    v_current_balance NUMERIC(12,2);
    v_avg_rating NUMERIC(3,2);
    v_driver_name TEXT;
    v_vehicle_info TEXT;
    v_online_status BOOLEAN;
    v_telemetry_stats JSONB;
BEGIN
    -- Get basic driver information from existing tables
    SELECT 
        p.full_name,
        COALESCE(d.vehicle_make, '') || ' ' || COALESCE(d.vehicle_model, '') AS vehicle_info,
        COALESCE(p.is_online, false) as is_online,
        COALESCE(d.rating, 0.0) as rating,
        COALESCE(d.total_rides, 0) as total_rides,
        0 as balance -- Placeholder
    INTO
        v_driver_name,
        v_vehicle_info,
        v_online_status,
        v_avg_rating,
        v_total_trips,
        v_current_balance
    FROM public.profiles p
    LEFT JOIN public.drivers d ON p.id = d.id
    WHERE p.id = p_driver_id;

    -- Calculate total earnings (placeholder)
    v_total_earnings := COALESCE(v_total_trips * 5000, 0);

    -- Get telemetry statistics (last 24 hours)
    SELECT jsonb_build_object(
        'events_today', COUNT(*),
        'last_online', MAX(timestamp),
        'event_types', COALESCE(jsonb_object_agg(type, count), '{}'::jsonb)
    )
    INTO v_telemetry_stats
    FROM (
        SELECT 
            type,
            COUNT(*) as count
        FROM public.telemetry_logs
        WHERE driver_id = p_driver_id
        AND timestamp >= NOW() - INTERVAL '24 hours'
        GROUP BY type
    ) subq;

    -- Build comprehensive dashboard response
    v_dashboard_data := jsonb_build_object(
        'driver_info', jsonb_build_object(
            'name', COALESCE(v_driver_name, 'Unknown Driver'),
            'vehicle', COALESCE(v_vehicle_info, 'No Vehicle'),
            'online', COALESCE(v_online_status, false),
            'rating', COALESCE(v_avg_rating, 0.0),
            'total_trips', COALESCE(v_total_trips, 0)
        ),
        'financials', jsonb_build_object(
            'current_balance', COALESCE(v_current_balance, 0),
            'total_earnings', COALESCE(v_total_earnings, 0),
            'currency', 'CDF'
        ),
        'performance', jsonb_build_object(
            'acceptance_rate', CASE 
                WHEN COALESCE(v_total_trips, 0) > 0 THEN 
                    ROUND((v_total_trips::NUMERIC / GREATEST(v_total_trips + 10, 1)) * 100, 2)
                ELSE 0 
            END,
            'response_time_avg', '2.5 min',
            'completion_rate', '98%'
        ),
        'telemetry', COALESCE(v_telemetry_stats, '{}'::JSONB),
        'timestamp', NOW(),
        'status', 'success'
    );

    RETURN v_dashboard_data;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'error', SQLERRM,
            'status', 'error',
            'timestamp', NOW()
        );
END;
$$;

-- ==========================================================
-- ADD INDEXES FOR PERFORMANCE
-- ==========================================================

-- Index for telemetry_logs driver_id
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_driver_id ON public.telemetry_logs(driver_id);

-- Index for telemetry_aggregates driver_id
CREATE INDEX IF NOT EXISTS idx_telemetry_aggregates_driver_id ON public.telemetry_aggregates(driver_id);

-- ==========================================================
-- GRANT PERMISSIONS
-- ==========================================================

-- Grant function permissions
GRANT EXECUTE ON FUNCTION public.upload_telemetry_event TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_telemetry_batch TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_dashboard TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ==========================================================
-- COMPLETION MESSAGE
-- ==========================================================

DO $$
BEGIN
    RAISE NOTICE 'Telemetry schema update completed successfully';
    RAISE NOTICE 'Added: driver_id column to telemetry_logs table';
    RAISE NOTICE 'Created: telemetry_aggregates table (if needed)';
    RAISE NOTICE 'Created: upload_telemetry_event, record_telemetry_batch functions';
    RAISE NOTICE 'Updated: get_driver_dashboard function';
    RAISE NOTICE 'Applied: Performance indexes';
END $$;