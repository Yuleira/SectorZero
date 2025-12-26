-- 《地球新主》核心数据表
-- Migration: 001_create_core_tables

-- ============================================
-- 1. profiles（用户资料）
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 启用 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看所有资料
CREATE POLICY "profiles_select_all" ON profiles
    FOR SELECT USING (true);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- RLS 策略：用户只能插入自己的资料
CREATE POLICY "profiles_insert_own" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- 2. territories（领地）
-- ============================================
CREATE TABLE territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL,  -- 路径点数组 [{lat, lng}, ...]
    area DOUBLE PRECISION NOT NULL,  -- 面积（平方米）
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX territories_user_id_idx ON territories(user_id);

-- 启用 RLS
ALTER TABLE territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看所有领地
CREATE POLICY "territories_select_all" ON territories
    FOR SELECT USING (true);

-- RLS 策略：用户只能插入自己的领地
CREATE POLICY "territories_insert_own" ON territories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "territories_update_own" ON territories
    FOR UPDATE USING (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "territories_delete_own" ON territories
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 3. pois（兴趣点）
-- ============================================
CREATE TABLE pois (
    id TEXT PRIMARY KEY,  -- 外部ID
    poi_type TEXT NOT NULL,  -- hospital/supermarket/factory等
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX pois_poi_type_idx ON pois(poi_type);
CREATE INDEX pois_discovered_by_idx ON pois(discovered_by);
CREATE INDEX pois_location_idx ON pois(latitude, longitude);

-- 启用 RLS
ALTER TABLE pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看所有兴趣点
CREATE POLICY "pois_select_all" ON pois
    FOR SELECT USING (true);

-- RLS 策略：已登录用户可以插入兴趣点
CREATE POLICY "pois_insert_authenticated" ON pois
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RLS 策略：只有发现者可以更新
CREATE POLICY "pois_update_discoverer" ON pois
    FOR UPDATE USING (auth.uid() = discovered_by);

-- ============================================
-- 4. 自动创建用户资料的触发器
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 当新用户注册时自动创建 profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
