-- Migration 021: Leaderboard RPC function
-- SECURITY DEFINER needed because player_buildings has own-only SELECT RLS

CREATE OR REPLACE FUNCTION public.get_leaderboard(
    p_category TEXT,
    p_time_period TEXT DEFAULT 'all_time',
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    rank BIGINT,
    user_id UUID,
    username TEXT,
    score DOUBLE PRECISION,
    total_players BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total BIGINT;
BEGIN
    -- Territory Area leaderboard
    IF p_category = 'territory_area' THEN
        CREATE TEMP TABLE _lb ON COMMIT DROP AS
        SELECT
            t.user_id AS uid,
            COALESCE(p.username, 'Unknown') AS uname,
            SUM(t.area) AS raw_score
        FROM territories t
        JOIN profiles p ON p.id = t.user_id
        WHERE t.is_active = true
          AND (
            p_time_period = 'all_time'
            OR (p_time_period = 'today' AND t.created_at >= date_trunc('day', now()))
            OR (p_time_period = 'this_week' AND t.created_at >= date_trunc('week', now()))
          )
        GROUP BY t.user_id, p.username;

    -- POI Count leaderboard
    ELSIF p_category = 'poi_count' THEN
        CREATE TEMP TABLE _lb ON COMMIT DROP AS
        SELECT
            po.discovered_by AS uid,
            COALESCE(p.username, 'Unknown') AS uname,
            COUNT(*)::DOUBLE PRECISION AS raw_score
        FROM pois po
        JOIN profiles p ON p.id = po.discovered_by
        WHERE (
            p_time_period = 'all_time'
            OR (p_time_period = 'today' AND po.discovered_at >= date_trunc('day', now()))
            OR (p_time_period = 'this_week' AND po.discovered_at >= date_trunc('week', now()))
          )
        GROUP BY po.discovered_by, p.username;

    -- Building Count leaderboard
    ELSIF p_category = 'building_count' THEN
        CREATE TEMP TABLE _lb ON COMMIT DROP AS
        SELECT
            pb.user_id AS uid,
            COALESCE(p.username, 'Unknown') AS uname,
            COUNT(*)::DOUBLE PRECISION AS raw_score
        FROM player_buildings pb
        JOIN profiles p ON p.id = pb.user_id
        WHERE pb.status = 'active'
          AND (
            p_time_period = 'all_time'
            OR (p_time_period = 'today' AND pb.created_at >= date_trunc('day', now()))
            OR (p_time_period = 'this_week' AND pb.created_at >= date_trunc('week', now()))
          )
        GROUP BY pb.user_id, p.username;

    ELSE
        RAISE EXCEPTION 'Invalid category: %', p_category;
    END IF;

    SELECT COUNT(*) INTO v_total FROM _lb;

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY _lb.raw_score DESC) AS rank,
        _lb.uid AS user_id,
        _lb.uname AS username,
        _lb.raw_score AS score,
        v_total AS total_players
    FROM _lb
    ORDER BY _lb.raw_score DESC
    LIMIT p_limit;
END;
$$;
