-- 《地球新主》领地表增强 - PostGIS 支持
-- Migration: 002_territories_postgis

-- ============================================
-- 1. 启用 PostGIS 扩展
-- ============================================
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- 2. 修改 territories 表：name 改为 nullable
-- ============================================
ALTER TABLE territories ALTER COLUMN name DROP NOT NULL;

-- ============================================
-- 3. 添加新字段
-- ============================================

-- PostGIS 地理多边形
ALTER TABLE territories ADD COLUMN IF NOT EXISTS polygon geography(Polygon, 4326);

-- 边界框坐标（用于快速空间查询）
ALTER TABLE territories ADD COLUMN IF NOT EXISTS bbox_min_lat DOUBLE PRECISION;
ALTER TABLE territories ADD COLUMN IF NOT EXISTS bbox_max_lat DOUBLE PRECISION;
ALTER TABLE territories ADD COLUMN IF NOT EXISTS bbox_min_lon DOUBLE PRECISION;
ALTER TABLE territories ADD COLUMN IF NOT EXISTS bbox_max_lon DOUBLE PRECISION;

-- 路径点数量
ALTER TABLE territories ADD COLUMN IF NOT EXISTS point_count INTEGER;

-- 时间戳
ALTER TABLE territories ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE territories ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- 是否有效（软删除标记）
ALTER TABLE territories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- ============================================
-- 4. 创建空间索引
-- ============================================
CREATE INDEX IF NOT EXISTS territories_polygon_idx ON territories USING GIST (polygon);
CREATE INDEX IF NOT EXISTS territories_bbox_idx ON territories (bbox_min_lat, bbox_max_lat, bbox_min_lon, bbox_max_lon);
CREATE INDEX IF NOT EXISTS territories_is_active_idx ON territories (is_active);
