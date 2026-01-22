-- =====================================================
-- 005_player_buildings.sql
-- 建筑系统 - 玩家建筑表
-- =====================================================
--
-- 执行方式：
-- 1. 通过 Supabase Dashboard → SQL Editor 执行
-- 2. 或通过 supabase db push 命令
-- 3. 或通过 Supabase MCP 工具执行

-- ============================================
-- player_buildings（玩家建筑表）
-- ============================================
CREATE TABLE IF NOT EXISTS player_buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    territory_id TEXT NOT NULL,
    template_id TEXT NOT NULL,
    building_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'constructing',  -- 'constructing' | 'active'
    level INTEGER NOT NULL DEFAULT 1,
    location_lat DOUBLE PRECISION,
    location_lon DOUBLE PRECISION,
    build_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    build_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 索引优化
-- ============================================

-- 用户 ID 索引（查询某用户的所有建筑）
CREATE INDEX IF NOT EXISTS player_buildings_user_id_idx 
    ON player_buildings(user_id);

-- 领地 ID 索引（查询某领地内的所有建筑）
CREATE INDEX IF NOT EXISTS player_buildings_territory_id_idx 
    ON player_buildings(territory_id);

-- 模板 ID 索引（统计某类型建筑的数量）
CREATE INDEX IF NOT EXISTS player_buildings_template_id_idx 
    ON player_buildings(template_id);

-- 状态索引（查询正在建造的建筑）
CREATE INDEX IF NOT EXISTS player_buildings_status_idx 
    ON player_buildings(status);

-- 复合索引（用于检查某领地内某模板的建筑数量）
CREATE INDEX IF NOT EXISTS player_buildings_territory_template_idx 
    ON player_buildings(territory_id, template_id);

-- ============================================
-- 行级安全策略（RLS）
-- ============================================

-- 启用 RLS
ALTER TABLE player_buildings ENABLE ROW LEVEL SECURITY;

-- SELECT: 用户只能查看自己的建筑
DROP POLICY IF EXISTS "player_buildings_select_own" ON player_buildings;
CREATE POLICY "player_buildings_select_own" ON player_buildings
    FOR SELECT 
    USING (auth.uid() = user_id);

-- INSERT: 用户只能插入自己的建筑
DROP POLICY IF EXISTS "player_buildings_insert_own" ON player_buildings;
CREATE POLICY "player_buildings_insert_own" ON player_buildings
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- UPDATE: 用户只能更新自己的建筑
DROP POLICY IF EXISTS "player_buildings_update_own" ON player_buildings;
CREATE POLICY "player_buildings_update_own" ON player_buildings
    FOR UPDATE 
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- DELETE: 用户只能删除自己的建筑
DROP POLICY IF EXISTS "player_buildings_delete_own" ON player_buildings;
CREATE POLICY "player_buildings_delete_own" ON player_buildings
    FOR DELETE 
    USING (auth.uid() = user_id);

-- ============================================
-- 触发器：自动更新 updated_at
-- ============================================

-- 复用已有的触发器函数（如果不存在则创建）
CREATE OR REPLACE FUNCTION update_buildings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS player_buildings_updated ON player_buildings;
CREATE TRIGGER player_buildings_updated
    BEFORE UPDATE ON player_buildings
    FOR EACH ROW 
    EXECUTE FUNCTION update_buildings_timestamp();

-- ============================================
-- 表注释
-- ============================================

COMMENT ON TABLE player_buildings IS '玩家建筑表，存储玩家在领地内建造的建筑物';
COMMENT ON COLUMN player_buildings.id IS '建筑唯一标识';
COMMENT ON COLUMN player_buildings.user_id IS '建筑所有者，关联 auth.users';
COMMENT ON COLUMN player_buildings.territory_id IS '所属领地 ID';
COMMENT ON COLUMN player_buildings.template_id IS '建筑模板 ID，对应 building_templates.json';
COMMENT ON COLUMN player_buildings.building_name IS '建筑名称（冗余存储，便于查询）';
COMMENT ON COLUMN player_buildings.status IS '建筑状态：constructing（建造中）| active（已激活）';
COMMENT ON COLUMN player_buildings.level IS '建筑等级，默认 1';
COMMENT ON COLUMN player_buildings.location_lat IS '建筑纬度（可选）';
COMMENT ON COLUMN player_buildings.location_lon IS '建筑经度（可选）';
COMMENT ON COLUMN player_buildings.build_started_at IS '开始建造时间';
COMMENT ON COLUMN player_buildings.build_completed_at IS '建造完成时间（constructing 状态时为 NULL）';
COMMENT ON COLUMN player_buildings.created_at IS '记录创建时间';
COMMENT ON COLUMN player_buildings.updated_at IS '记录更新时间';
