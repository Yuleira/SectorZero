
-- 004_player_locations.sql
-- Reconciliation migration: player_locations already exists

CREATE TABLE IF NOT EXISTS player_locations (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  location geography(Point, 4326) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_online BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_player_locations_geo
  ON player_locations USING GIST(location);

CREATE INDEX IF NOT EXISTS idx_player_locations_updated
  ON player_locations(last_updated_at);

CREATE INDEX IF NOT EXISTS idx_player_locations_online
  ON player_locations(is_online)
  WHERE is_online = TRUE;

ALTER TABLE player_locations ENABLE ROW LEVEL SECURITY;


-- RLS 策略：用户只能插入/更新自己的位置
DROP POLICY IF EXISTS "Users can insert own location" 
    ON player_locations;

CREATE POLICY "Users can insert own location"
    ON player_locations
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own location"
    ON player_locations;

CREATE POLICY "Users can update own location"
    ON player_locations
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户可以查看自己的位置（用于调试）
DROP POLICY IF EXISTS "Users can view own location"
    ON player_locations;

CREATE POLICY "Users can view own location"
    ON player_locations
    FOR SELECT
    USING (auth.uid() = user_id);

-- 注意：不提供查看其他玩家位置的策略，保护隐私


-- =====================================================
-- 附近玩家计数函数
-- 返回指定范围内的在线玩家数量（不含调用者自己）
-- =====================================================
CREATE OR REPLACE FUNCTION nearby_players_count(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 1000,
    p_timeout_minutes INTEGER DEFAULT 5
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    player_count INTEGER;
    query_point geography;
BEGIN
    -- 构建查询点
    query_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

    -- 统计范围内的在线玩家（排除自己）
    SELECT COUNT(*) INTO player_count
    FROM player_locations
    WHERE user_id != auth.uid()
      AND is_online = TRUE
      AND last_updated_at > NOW() - (p_timeout_minutes || ' minutes')::INTERVAL
      AND ST_DWithin(location, query_point, p_radius_meters);

    RETURN COALESCE(player_count, 0);
END;
$$;

-- 授予已认证用户调用权限
GRANT EXECUTE ON FUNCTION nearby_players_count TO authenticated;


-- =====================================================
-- 位置上报函数（Upsert）
-- 简化客户端调用，自动处理插入或更新
-- =====================================================
CREATE OR REPLACE FUNCTION upsert_player_location(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_is_online BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_location geography;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 构建地理位置点
    v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

    -- Upsert 位置数据
    INSERT INTO player_locations (user_id, location, latitude, longitude, last_updated_at, is_online)
    VALUES (v_user_id, v_location, p_latitude, p_longitude, NOW(), p_is_online)
    ON CONFLICT (user_id)
    DO UPDATE SET
        location = EXCLUDED.location,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        last_updated_at = NOW(),
        is_online = EXCLUDED.is_online;
END;
$$;

-- 授予已认证用户调用权限
GRANT EXECUTE ON FUNCTION upsert_player_location TO authenticated;


-- =====================================================
-- 标记离线函数
-- 用于 App 进入后台时调用
-- =====================================================
CREATE OR REPLACE FUNCTION mark_player_offline()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE player_locations
    SET is_online = FALSE,
        last_updated_at = NOW()
    WHERE user_id = auth.uid();
END;
$$;

-- 授予已认证用户调用权限
GRANT EXECUTE ON FUNCTION mark_player_offline TO authenticated;


-- =====================================================
-- 添加注释
-- =====================================================
COMMENT ON TABLE player_locations IS '玩家实时位置表，用于附近玩家密度检测';
COMMENT ON COLUMN player_locations.user_id IS '玩家ID，关联 profiles 表';
COMMENT ON COLUMN player_locations.location IS 'PostGIS 地理位置点，用于空间查询';
COMMENT ON COLUMN player_locations.latitude IS '纬度，冗余存储便于客户端使用';
COMMENT ON COLUMN player_locations.longitude IS '经度，冗余存储便于客户端使用';
COMMENT ON COLUMN player_locations.last_updated_at IS '最后更新时间，用于判断在线状态';
COMMENT ON COLUMN player_locations.is_online IS '是否在线，App 进入后台时设为 false';

COMMENT ON FUNCTION nearby_players_count IS '查询指定范围内的在线玩家数量（不含自己）';
COMMENT ON FUNCTION upsert_player_location IS '上报/更新玩家位置';
COMMENT ON FUNCTION mark_player_offline IS '标记玩家离线';
