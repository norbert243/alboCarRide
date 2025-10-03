-- SQL Function for updating trip status with proper validation and notifications
-- This function handles the complete trip lifecycle management

CREATE OR REPLACE FUNCTION update_trip_status(
  trip_id UUID,
  new_status TEXT,
  reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_trip RECORD;
  driver_user_id UUID;
  rider_user_id UUID;
  result JSONB;
BEGIN
  -- Get current trip details
  SELECT * INTO current_trip 
  FROM trips 
  WHERE id = trip_id;
  
  -- Validate trip exists
  IF current_trip IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Trip not found',
      'message', 'The specified trip does not exist'
    );
  END IF;
  
  -- Validate status transition
  IF NOT validate_trip_status_transition(current_trip.status, new_status) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid status transition',
      'message', format('Cannot transition from %s to %s', current_trip.status, new_status)
    );
  END IF;
  
  -- Update trip status
  UPDATE trips 
  SET 
    status = new_status,
    updated_at = NOW(),
    cancellation_reason = CASE 
      WHEN new_status = 'cancelled' THEN reason 
      ELSE cancellation_reason 
    END,
    completed_at = CASE 
      WHEN new_status = 'completed' THEN NOW() 
      ELSE completed_at 
    END,
    started_at = CASE 
      WHEN new_status = 'in_progress' THEN NOW() 
      ELSE started_at 
    END
  WHERE id = trip_id;
  
  -- Get user IDs for notifications
  SELECT driver_id INTO driver_user_id FROM trips WHERE id = trip_id;
  SELECT rider_id INTO rider_user_id FROM trips WHERE id = trip_id;
  
  -- Create notifications based on status change
  IF new_status = 'accepted' THEN
    -- Notify rider that driver accepted
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
      rider_user_id,
      'Ride Accepted',
      'Your ride has been accepted by a driver',
      'trip_accepted',
      jsonb_build_object('trip_id', trip_id, 'driver_id', driver_user_id)
    );
    
  ELSIF new_status = 'driver_arrived' THEN
    -- Notify rider that driver arrived
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
      rider_user_id,
      'Driver Arrived',
      'Your driver has arrived at the pickup location',
      'driver_arrived',
      jsonb_build_object('trip_id', trip_id)
    );
    
  ELSIF new_status = 'in_progress' THEN
    -- Notify rider that trip started
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
      rider_user_id,
      'Trip Started',
      'Your trip has started',
      'trip_started',
      jsonb_build_object('trip_id', trip_id)
    );
    
  ELSIF new_status = 'completed' THEN
    -- Notify both rider and driver about completion
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES 
    (
      rider_user_id,
      'Trip Completed',
      'Your trip has been completed',
      'trip_completed',
      jsonb_build_object('trip_id', trip_id)
    ),
    (
      driver_user_id,
      'Trip Completed',
      'You have completed the trip',
      'trip_completed',
      jsonb_build_object('trip_id', trip_id)
    );
    
  ELSIF new_status = 'cancelled' THEN
    -- Notify the other party about cancellation
    IF auth.uid() = driver_user_id THEN
      -- Driver cancelled, notify rider
      INSERT INTO notifications (user_id, title, message, type, data)
      VALUES (
        rider_user_id,
        'Trip Cancelled',
        'The driver cancelled your ride',
        'trip_cancelled',
        jsonb_build_object('trip_id', trip_id, 'reason', reason)
      );
    ELSE
      -- Rider cancelled, notify driver
      INSERT INTO notifications (user_id, title, message, type, data)
      VALUES (
        driver_user_id,
        'Trip Cancelled',
        'The rider cancelled the ride',
        'trip_cancelled',
        jsonb_build_object('trip_id', trip_id, 'reason', reason)
      );
    END IF;
  END IF;
  
  -- Return success response
  result := jsonb_build_object(
    'success', true,
    'trip_id', trip_id,
    'old_status', current_trip.status,
    'new_status', new_status,
    'message', 'Trip status updated successfully'
  );
  
  RETURN result;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Return error response
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'message', 'Failed to update trip status'
    );
END;
$$;

-- Helper function to validate status transitions
CREATE OR REPLACE FUNCTION validate_trip_status_transition(
  current_status TEXT,
  new_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Define valid status transitions
  RETURN CASE
    -- From pending (just created)
    WHEN current_status = 'pending' AND new_status IN ('accepted', 'cancelled') THEN true
    
    -- From accepted (driver accepted)
    WHEN current_status = 'accepted' AND new_status IN ('driver_arrived', 'cancelled') THEN true
    
    -- From driver_arrived (driver at pickup)
    WHEN current_status = 'driver_arrived' AND new_status IN ('in_progress', 'cancelled') THEN true
    
    -- From in_progress (trip ongoing)
    WHEN current_status = 'in_progress' AND new_status IN ('completed', 'cancelled') THEN true
    
    -- From completed (final state)
    WHEN current_status = 'completed' THEN false
    
    -- From cancelled (final state)
    WHEN current_status = 'cancelled' THEN false
    
    -- Default: invalid transition
    ELSE false
  END;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_trip_status TO authenticated;
GRANT EXECUTE ON FUNCTION validate_trip_status_transition TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_driver_id ON trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_rider_id ON trips(rider_id);
CREATE INDEX IF NOT EXISTS idx_trips_created_at ON trips(created_at DESC);