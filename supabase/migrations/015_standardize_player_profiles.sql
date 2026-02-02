-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 015_standardize_player_profiles.sql
-- Day 36 Fix: Standardize profile table to player_profiles
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ISSUE: Table name mismatch between DB function and Swift code
-- SOLUTION: Standardize on 'player_profiles' for game-specific profile data
--
-- Execute: supabase db push OR run in Supabase SQL Editor

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: Create player_profiles table (or rename from user_profiles)
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop user_profiles if it exists and recreate as player_profiles
DROP TABLE IF EXISTS public.user_profiles CASCADE;

-- Create the standardized player_profiles table
CREATE TABLE IF NOT EXISTS public.player_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    callsign TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_player_profiles_user_id ON public.player_profiles(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: Enable RLS and create policies
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own profile" ON public.player_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.player_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.player_profiles;

-- Create RLS policies
CREATE POLICY "Users can view own profile"
    ON public.player_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON public.player_profiles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON public.player_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: Create auto-update trigger for updated_at
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_player_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_player_profiles_updated_at ON public.player_profiles;
CREATE TRIGGER trigger_update_player_profiles_updated_at
    BEFORE UPDATE ON public.player_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_player_profiles_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 4: Update send_channel_message to use player_profiles
-- ═══════════════════════════════════════════════════════════════════════════

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

    -- Check if user is subscribed to the channel
    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'You must subscribe to send messages';
    END IF;

    -- Get user callsign from player_profiles (Day 36 standardized table)
    BEGIN
        SELECT COALESCE(callsign, 'Anonymous')
        INTO v_callsign
        FROM public.player_profiles
        WHERE user_id = v_user_id;
    EXCEPTION
        WHEN undefined_table THEN
            v_callsign := 'Anonymous';
        WHEN no_data_found THEN
            v_callsign := 'Anonymous';
    END;

    -- Fallback if no profile found
    IF v_callsign IS NULL THEN
        v_callsign := 'Anonymous';
    END IF;

    -- Build PostGIS point (optional, for server-side queries)
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    END IF;

    -- INSERT with BOTH PostGIS AND numerical coordinates
    INSERT INTO channel_messages (
        channel_id,
        sender_id,
        sender_callsign,
        content,
        sender_location,
        sender_latitude,
        sender_longitude,
        metadata
    ) VALUES (
        p_channel_id,
        v_user_id,
        v_callsign,
        p_content,
        v_point,
        p_latitude,
        p_longitude,
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION send_channel_message(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 5: Verification queries
-- ═══════════════════════════════════════════════════════════════════════════

-- Run these to verify:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'player_profiles';
-- SELECT * FROM pg_policies WHERE tablename = 'player_profiles';
