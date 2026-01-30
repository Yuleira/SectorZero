-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: Numerical Coordinates Protocol
-- Day 35-C: Bypass PostGIS hex parsing by providing direct lat/lon in payload
-- ═══════════════════════════════════════════════════════════════════════════

-- STEP 1: Add numerical coordinate columns to channel_messages
ALTER TABLE channel_messages
ADD COLUMN IF NOT EXISTS sender_latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS sender_longitude DOUBLE PRECISION;

-- STEP 2: Backfill existing messages with coordinates from PostGIS
UPDATE channel_messages
SET
    sender_latitude = ST_Y(sender_location::geometry),
    sender_longitude = ST_X(sender_location::geometry)
WHERE sender_location IS NOT NULL
  AND sender_latitude IS NULL;

-- STEP 3: Update RPC to INSERT numerical coordinates DIRECTLY
-- This ensures Realtime payload contains numerical values immediately
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id UUID,
    p_content TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_callsign TEXT;
    v_message_id UUID;
    v_point GEOMETRY(POINT, 4326);
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user callsign
    SELECT callsign INTO v_callsign
    FROM player_profiles
    WHERE user_id = v_user_id;

    -- Build PostGIS point (optional, for server-side queries)
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    END IF;

    -- INSERT with BOTH PostGIS AND numerical coordinates
    -- Numerical coordinates are the CLIENT PROTOCOL - directly in payload
    INSERT INTO channel_messages (
        channel_id,
        sender_id,
        sender_callsign,
        content,
        sender_location,
        sender_latitude,      -- DIRECT: not via trigger, in payload immediately
        sender_longitude,     -- DIRECT: not via trigger, in payload immediately
        metadata
    ) VALUES (
        p_channel_id,
        v_user_id,
        v_callsign,
        p_content,
        v_point,
        p_latitude,           -- Passed directly to INSERT
        p_longitude,          -- Passed directly to INSERT
        CASE
            WHEN p_device_type IS NOT NULL
            THEN jsonb_build_object('device_type', p_device_type)
            ELSE NULL
        END
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$;

-- STEP 4: Grant execute permission
GRANT EXECUTE ON FUNCTION send_channel_message(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;
