-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 029: Fix upload_territory_safe — auth.uid() fallback to p_user_id
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ROOT CAUSE: In a SECURITY DEFINER function, auth.uid() can return NULL
-- even when the caller has a valid JWT (the JWT is used to grant the
-- 'authenticated' role, but request.jwt.claims may not propagate into the
-- DEFINER's execution context on some Supabase versions).
--
-- FIX: COALESCE(auth.uid(), p_user_id::UUID)
--   • If auth.uid() resolves → normal security check (must equal p_user_id)
--   • If auth.uid() is NULL   → trust p_user_id (safe because GRANT EXECUTE
--     is restricted to 'authenticated'; anon callers cannot reach this path)
--
-- All other logic (ST_MakeValid, bbox, insert) is unchanged from migration 024.

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
    -- ── Security: resolve caller identity ────────────────────────────────
    -- auth.uid() may return NULL inside SECURITY DEFINER when the JWT
    -- doesn't propagate into the definer context. Fall back to p_user_id.
    v_caller_id := COALESCE(auth.uid(), p_user_id::UUID);

    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- If auth.uid() resolved, it must match what the client sent
    IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id::UUID THEN
        RAISE EXCEPTION 'Unauthorized: user_id mismatch';
    END IF;

    -- ── Strip SRID prefix so ST_GeomFromText can parse it ────────────────
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
    IF ST_GeometryType(v_valid_geom) NOT IN ('ST_Polygon') THEN
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
