-- ============================
-- get_driver_dashboard RPC Function
-- ============================

CREATE OR REPLACE FUNCTION get_driver_dashboard(driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  dashboard_data jsonb;
  driver_balance numeric;
  today_earnings numeric;
  weekly_earnings numeric;
  completed_trips_count integer;
  driver_rating numeric;
BEGIN
  -- Get wallet balance
  SELECT COALESCE(balance, 0.0)
  INTO driver_balance
  FROM driver_wallets
  WHERE driver_wallets.driver_id = get_driver_dashboard.driver_id;

  -- Get today's earnings (trips completed today)
  SELECT COALESCE(SUM(final_price), 0.0)
  INTO today_earnings
  FROM trips
  WHERE trips.driver_id = get_driver_dashboard.driver_id
    AND trips.status = 'completed'
    AND DATE(trips.completed_at) = CURRENT_DATE;

  -- Get weekly earnings (trips completed this week)
  SELECT COALESCE(SUM(final_price), 0.0)
  INTO weekly_earnings
  FROM trips
  WHERE trips.driver_id = get_driver_dashboard.driver_id
    AND trips.status = 'completed'
    AND DATE(trips.completed_at) >= DATE_TRUNC('week', CURRENT_DATE);

  -- Get completed trips count
  SELECT COUNT(*)
  INTO completed_trips_count
  FROM trips
  WHERE trips.driver_id = get_driver_dashboard.driver_id
    AND trips.status = 'completed';

  -- Get driver rating from profiles table
  SELECT COALESCE(rating, 0.0)
  INTO driver_rating
  FROM profiles
  WHERE profiles.id = get_driver_dashboard.driver_id;

  -- Build dashboard data
  dashboard_data := jsonb_build_object(
    'balance', driver_balance,
    'today_earnings', today_earnings,
    'weekly_earnings', weekly_earnings,
    'completed_trips', completed_trips_count,
    'rating', driver_rating
  );

  RETURN dashboard_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_driver_dashboard(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_driver_dashboard(uuid) TO service_role;

-- Comment for documentation
COMMENT ON FUNCTION get_driver_dashboard(uuid) IS 'Returns comprehensive dashboard data for a driver including earnings, balance, and performance metrics';