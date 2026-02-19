-- 022: Add atomic increment_distance_walked RPC
-- Prevents read-modify-write race on total_distance_walked

CREATE OR REPLACE FUNCTION increment_distance_walked(p_user_id UUID, p_delta DOUBLE PRECISION)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE player_profiles
  SET total_distance_walked = COALESCE(total_distance_walked, 0) + p_delta,
      updated_at = NOW()
  WHERE user_id = p_user_id;
END;
$$;
