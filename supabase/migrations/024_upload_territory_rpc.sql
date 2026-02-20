-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 024: upload_territory_safe RPC — Polygon Repair via ST_MakeValid
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ROOT CAUSE: GPS paths with self-intersections produce invalid WKT polygons.
-- PostGIS rejects these on INSERT, silently failing the territory claim.
--
-- FIX: Server-side RPC that applies ST_MakeValid() before inserting.
-- If the polygon is a GeometryCollection after repair, extract the largest
-- polygon component so the territory is saved rather than rejected.
--
-- Swift caller: TerritoryManager.uploadTerritory (via supabase.rpc)

CREATE OR REPLACE FUNCTION upload_territory_safe(
    p_user_id       TEXT,
    p_path          JSONB,
    p_polygon_wkt   TEXT,
    p_bbox_min_lat  DOUBLE PRECISION,
    p_bbox_max_lat  DOUBLE PRECISION,
    p_bbox_min_lon  DOUBLE PRECISION,
    p_bbox_max_lon  DOUBLE PRECISION,
    p_area          DOUBLE PRECISION,
    p_point_count   INTEGER,
    p_started_at    TEXT,
    p_completed_at  TEXT,
    p_distance_walked DOUBLE PRECISION DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id    UUID;
    v_geom         GEOMETRY;
    v_valid_geom   GEOMETRY;
    v_geography    GEOGRAPHY;
    v_territory_id UUID;
    v_wkt_clean    TEXT;
BEGIN
    -- ── Security: caller must own the territory ──────────────────────────
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_caller_id::TEXT != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: user_id mismatch';
    END IF;

    -- ── Strip SRID prefix so ST_GeomFromText can parse it ────────────────
    -- Input format: "SRID=4326;POLYGON((lon lat, ...))"
    v_wkt_clean := regexp_replace(p_polygon_wkt, '^SRID=\d+;', '');

    -- ── Parse geometry ───────────────────────────────────────────────────
    v_geom := ST_GeomFromText(v_wkt_clean, 4326);

    IF v_geom IS NULL OR ST_IsEmpty(v_geom) THEN
        RAISE EXCEPTION 'Cannot parse polygon WKT: %', p_polygon_wkt;
    END IF;

    -- ── Repair self-intersections with ST_MakeValid ──────────────────────
    IF NOT ST_IsValid(v_geom) THEN
        v_valid_geom := ST_MakeValid(v_geom);
    ELSE
        v_valid_geom := v_geom;
    END IF;

    -- ── If MakeValid returned a collection, extract largest polygon ───────
    -- (self-intersecting figure-8 paths become MultiPolygon or GeomCollection)
    IF ST_GeometryType(v_valid_geom) NOT IN ('ST_Polygon') THEN
        -- CollectionExtract(geom, 3) extracts only polygon components
        v_valid_geom := ST_GeometryN(
            ST_CollectionExtract(v_valid_geom, 3),
            1
        );
    END IF;

    IF v_valid_geom IS NULL OR ST_IsEmpty(v_valid_geom) THEN
        RAISE EXCEPTION 'Polygon is unrepairable — too few valid points';
    END IF;

    -- ── Cast to geography(Polygon, 4326) for storage ─────────────────────
    v_geography := v_valid_geom::GEOGRAPHY;

    -- ── Insert territory ─────────────────────────────────────────────────
    INSERT INTO territories (
        user_id,
        path,
        polygon,
        bbox_min_lat, bbox_max_lat,
        bbox_min_lon, bbox_max_lon,
        area,
        point_count,
        started_at,
        completed_at,
        is_active,
        distance_walked
    ) VALUES (
        v_caller_id,
        p_path,
        v_geography,
        p_bbox_min_lat, p_bbox_max_lat,
        p_bbox_min_lon, p_bbox_max_lon,
        p_area,
        p_point_count,
        p_started_at::TIMESTAMPTZ,
        p_completed_at::TIMESTAMPTZ,
        true,
        p_distance_walked
    )
    RETURNING id INTO v_territory_id;

    RETURN v_territory_id;
END;
$$;

GRANT EXECUTE ON FUNCTION upload_territory_safe(
    TEXT, JSONB, TEXT,
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    DOUBLE PRECISION, INTEGER, TEXT, TEXT, DOUBLE PRECISION
) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- Test the function manually:
-- SELECT upload_territory_safe(
--     auth.uid()::text,
--     '[{"lat":31.2,"lon":121.4}]'::jsonb,
--     'SRID=4326;POLYGON((121.4 31.2, 121.41 31.2, 121.41 31.21, 121.4 31.2))',
--     31.2, 31.21, 121.4, 121.41, 1000, 3,
--     now()::text, now()::text, 500
-- );
-- ═══════════════════════════════════════════════════════════════════════════
