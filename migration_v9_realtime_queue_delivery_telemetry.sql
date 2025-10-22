-- Migration v9: Enhanced Realtime Queue Management, FCM Delivery Receipts, and Telemetry Batching
-- Safe DROP/CREATE patterns for idempotent execution

-- =============================================================================
-- PUSH DELIVERY LOGS TABLE
-- =============================================================================

-- Drop existing table if it exists (safe for migrations)
DROP TABLE IF EXISTS public.push_delivery_logs CASCADE;

-- Create push delivery logs table
CREATE TABLE public.push_delivery_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    push_id uuid NOT NULL REFERENCES public.push_notifications(id) ON DELETE CASCADE,
    device_token text,
    status text NOT NULL CHECK (status IN ('delivered','failed','opened','clicked','unknown')),
    details jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_push_id ON public.push_delivery_logs(push_id);
CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_device_token ON public.push_delivery_logs(device_token);
CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_status ON public.push_delivery_logs(status);
CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_created_at ON public.push_delivery_logs(created_at);

-- Enable RLS
ALTER TABLE public.push_delivery_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for push_delivery_logs
DROP POLICY IF EXISTS "Users can view their own delivery logs" ON public.push_delivery_logs;
CREATE POLICY "Users can view their own delivery logs" ON public.push_delivery_logs
    FOR SELECT USING (
        push_id IN (
            SELECT id FROM public.push_notifications 
            WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Service role can manage delivery logs" ON public.push_delivery_logs;
CREATE POLICY "Service role can manage delivery logs" ON public.push_delivery_logs
    FOR ALL USING (auth.role() = 'service_role');

-- =============================================================================
-- ENHANCED PUSH NOTIFICATIONS TABLE
-- =============================================================================

-- Add new columns to push_notifications table if they don't exist
DO $$ 
BEGIN
    -- Add retry_count column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'push_notifications' AND column_name = 'retry_count') THEN
        ALTER TABLE public.push_notifications ADD COLUMN retry_count integer DEFAULT 0;
    END IF;

    -- Add last_retry_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'push_notifications' AND column_name = 'last_retry_at') THEN
        ALTER TABLE public.push_notifications ADD COLUMN last_retry_at timestamptz;
    END IF;

    -- Add delivery_attempts column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'push_notifications' AND column_name = 'delivery_attempts') THEN
        ALTER TABLE public.push_notifications ADD COLUMN delivery_attempts integer DEFAULT 0;
    END IF;
END $$;

-- Create indexes for enhanced push notifications
CREATE INDEX IF NOT EXISTS idx_push_notifications_retry_count ON public.push_notifications(retry_count);
CREATE INDEX IF NOT EXISTS idx_push_notifications_last_retry_at ON public.push_notifications(last_retry_at);
CREATE INDEX IF NOT EXISTS idx_push_notifications_delivery_attempts ON public.push_notifications(delivery_attempts);

-- =============================================================================
-- ENHANCED TELEMETRY LOGS TABLE
-- =============================================================================

-- Add new columns to telemetry_logs table if they don't exist
DO $$ 
BEGIN
    -- Add batch_id column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'telemetry_logs' AND column_name = 'batch_id') THEN
        ALTER TABLE public.telemetry_logs ADD COLUMN batch_id uuid;
    END IF;

    -- Add processed_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'telemetry_logs' AND column_name = 'processed_at') THEN
        ALTER TABLE public.telemetry_logs ADD COLUMN processed_at timestamptz;
    END IF;
END $$;

-- Create indexes for enhanced telemetry
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_batch_id ON public.telemetry_logs(batch_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_logs_processed_at ON public.telemetry_logs(processed_at);

-- =============================================================================
-- RPC FUNCTIONS FOR MIGRATION V9
-- =============================================================================

-- Function to fetch pending pushes for server-side worker
CREATE OR REPLACE FUNCTION public.fetch_pending_pushes(
    p_limit integer DEFAULT 10
)
RETURNS TABLE(
    id uuid,
    user_id uuid,
    device_token text,
    title text,
    body text,
    data jsonb,
    status text,
    retry_count integer,
    delivery_attempts integer,
    created_at timestamptz
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pn.id,
        pn.user_id,
        pn.device_token,
        pn.title,
        pn.body,
        pn.data,
        pn.status,
        pn.retry_count,
        pn.delivery_attempts,
        pn.created_at
    FROM public.push_notifications pn
    WHERE pn.status = 'pending'
        AND (pn.retry_count < 3 OR pn.retry_count IS NULL)
        AND (pn.last_retry_at IS NULL OR pn.last_retry_at < now() - interval '5 minutes')
    ORDER BY pn.created_at ASC
    LIMIT p_limit;
END;
$$;

-- Function to mark push as sent
CREATE OR REPLACE FUNCTION public.mark_push_sent(
    p_push_id uuid
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.push_notifications 
    SET 
        status = 'sent',
        sent_at = now(),
        delivery_attempts = COALESCE(delivery_attempts, 0) + 1
    WHERE id = p_push_id;
END;
$$;

-- Function to mark push as failed
CREATE OR REPLACE FUNCTION public.mark_push_failed(
    p_push_id uuid,
    p_error text DEFAULT NULL
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.push_notifications 
    SET 
        status = 'failed',
        error_message = p_error,
        retry_count = COALESCE(retry_count, 0) + 1,
        last_retry_at = now(),
        delivery_attempts = COALESCE(delivery_attempts, 0) + 1
    WHERE id = p_push_id;
END;
$$;

-- Function to record delivery receipt
CREATE OR REPLACE FUNCTION public.record_delivery_receipt(
    p_push_id uuid,
    p_device_token text,
    p_status text,
    p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert delivery receipt
    INSERT INTO public.push_delivery_logs (
        push_id,
        device_token,
        status,
        details
    ) VALUES (
        p_push_id,
        p_device_token,
        p_status,
        p_details
    );

    -- Update push notification status if delivered
    IF p_status = 'delivered' THEN
        UPDATE public.push_notifications 
        SET status = 'delivered'
        WHERE id = p_push_id AND status != 'delivered';
    END IF;
END;
$$;

-- Function to flush telemetry in batch
CREATE OR REPLACE FUNCTION public.flush_telemetry(
    p_payloads jsonb[]
)
RETURNS integer
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id uuid := gen_random_uuid();
    v_inserted_count integer := 0;
    v_payload jsonb;
BEGIN
    -- Insert all telemetry logs in batch
    FOREACH v_payload IN ARRAY p_payloads
    LOOP
        INSERT INTO public.telemetry_logs (
            type,
            message,
            meta,
            timestamp,
            batch_id,
            processed_at
        ) VALUES (
            v_payload->>'type',
            v_payload->>'message',
            COALESCE(v_payload->'meta', '{}'::jsonb),
            COALESCE((v_payload->>'timestamp')::timestamptz, now()),
            v_batch_id,
            now()
        );
        v_inserted_count := v_inserted_count + 1;
    END LOOP;

    RETURN v_inserted_count;
END;
$$;

-- Function to get push delivery statistics
CREATE OR REPLACE FUNCTION public.get_push_delivery_stats(
    p_days integer DEFAULT 7
)
RETURNS TABLE(
    total_pushes bigint,
    sent_pushes bigint,
    failed_pushes bigint,
    delivered_pushes bigint,
    delivery_rate numeric,
    avg_delivery_time interval
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH push_stats AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'sent') as sent,
            COUNT(*) FILTER (WHERE status = 'failed') as failed,
            COUNT(*) FILTER (WHERE status = 'delivered') as delivered
        FROM public.push_notifications
        WHERE created_at >= now() - (p_days || ' days')::interval
    ),
    delivery_times AS (
        SELECT 
            AVG(pdl.created_at - pn.created_at) as avg_time
        FROM public.push_delivery_logs pdl
        JOIN public.push_notifications pn ON pdl.push_id = pn.id
        WHERE pdl.status = 'delivered'
          AND pn.created_at >= now() - (p_days || ' days')::interval
    )
    SELECT 
        ps.total as total_pushes,
        ps.sent as sent_pushes,
        ps.failed as failed_pushes,
        ps.delivered as delivered_pushes,
        CASE 
            WHEN ps.total > 0 THEN ROUND((ps.delivered::numeric / ps.total::numeric) * 100, 2)
            ELSE 0 
        END as delivery_rate,
        COALESCE(dt.avg_time, '0'::interval) as avg_delivery_time
    FROM push_stats ps, delivery_times dt;
END;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================

-- Grant permissions
GRANT ALL ON public.push_delivery_logs TO service_role;
GRANT SELECT ON public.push_delivery_logs TO authenticated;

GRANT EXECUTE ON FUNCTION public.fetch_pending_pushes TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_push_sent TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_push_failed TO service_role;
GRANT EXECUTE ON FUNCTION public.record_delivery_receipt TO service_role;
GRANT EXECUTE ON FUNCTION public.flush_telemetry TO service_role;
GRANT EXECUTE ON FUNCTION public.get_push_delivery_stats TO service_role;

-- =============================================================================
-- MIGRATION COMPLETION LOG
-- =============================================================================

-- Log migration completion
INSERT INTO public.telemetry_logs (
    type,
    message,
    meta,
    timestamp
) VALUES (
    'MIGRATION_V9_COMPLETED',
    'Migration v9: Enhanced Realtime Queue Management, FCM Delivery Receipts, and Telemetry Batching applied successfully',
    '{"migration_version": 9, "features": ["push_delivery_logs", "enhanced_retry_logic", "batch_telemetry", "delivery_receipts"]}'::jsonb,
    now()
);

-- =============================================================================
-- MIGRATION SUMMARY
-- =============================================================================

/*
Migration v9 Features:
1. Push Delivery Logs Table - Track FCM delivery receipts
2. Enhanced Push Notifications - Retry logic and delivery tracking
3. Batch Telemetry Flushing - Reduce network calls for telemetry
4. Server-side Worker Functions - Process pending pushes efficiently
5. Delivery Statistics - Monitor push notification performance

Security:
- All RPC functions are SECURITY DEFINER for service_role access
- RLS policies ensure users can only see their own delivery logs
- Safe DROP/CREATE patterns for idempotent execution

Usage:
1. Server worker calls fetch_pending_pushes() to get pending notifications
2. After FCM delivery, call mark_push_sent() or mark_push_failed()
3. Device calls record_delivery_receipt() when notification is received
4. TelemetryService calls flush_telemetry() to batch insert logs
*/