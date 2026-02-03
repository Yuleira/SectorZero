-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 017_add_iap_fields_to_profile.sql
-- Description: Add In-App Purchase entitlement fields to player_profiles
-- ═══════════════════════════════════════════════════════════════════════════

-- STEP 1: Add IAP columns to player_profiles
-- ───────────────────────────────────────────────────────────────────────────

ALTER TABLE public.player_profiles
ADD COLUMN IF NOT EXISTS membership_tier INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS shards_balance INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS permanent_unlocks TEXT[] DEFAULT '{}';

-- Add column comments for documentation
COMMENT ON COLUMN public.player_profiles.membership_tier IS
    'Subscription tier: 0=free, 1=scavenger, 2=pioneer, 3=archon';
COMMENT ON COLUMN public.player_profiles.shards_balance IS
    'Premium currency balance (Aether Shards - consumable)';
COMMENT ON COLUMN public.player_profiles.permanent_unlocks IS
    'Array of purchased non-consumable product IDs';

-- STEP 2: Create index for membership tier queries
-- ───────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_player_profiles_membership_tier
ON public.player_profiles(membership_tier);

-- STEP 3: RPC function to safely update shards balance
-- ───────────────────────────────────────────────────────────────────────────
-- Prevents negative balance and ensures atomic updates

CREATE OR REPLACE FUNCTION public.update_shards_balance(
    p_user_id UUID,
    p_delta INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new_balance INTEGER;
BEGIN
    -- Verify caller is the owner
    IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: can only update own shards balance';
    END IF;

    -- Update balance (clamped to 0 minimum)
    UPDATE public.player_profiles
    SET
        shards_balance = GREATEST(0, COALESCE(shards_balance, 0) + p_delta),
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING shards_balance INTO v_new_balance;

    IF v_new_balance IS NULL THEN
        RAISE EXCEPTION 'Profile not found for user %', p_user_id;
    END IF;

    RETURN v_new_balance;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.update_shards_balance(UUID, INTEGER) TO authenticated;

-- STEP 4: RPC function to add permanent unlock
-- ───────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.add_permanent_unlock(
    p_user_id UUID,
    p_product_id TEXT
)
RETURNS TEXT[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_unlocks TEXT[];
BEGIN
    -- Verify caller is the owner
    IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: can only update own unlocks';
    END IF;

    -- Add to array if not already present
    UPDATE public.player_profiles
    SET
        permanent_unlocks = array_append(
            COALESCE(permanent_unlocks, '{}'),
            p_product_id
        ),
        updated_at = now()
    WHERE user_id = p_user_id
      AND NOT (COALESCE(permanent_unlocks, '{}') @> ARRAY[p_product_id])
    RETURNING permanent_unlocks INTO v_unlocks;

    -- If no update happened, return current unlocks
    IF v_unlocks IS NULL THEN
        SELECT permanent_unlocks INTO v_unlocks
        FROM public.player_profiles
        WHERE user_id = p_user_id;
    END IF;

    RETURN v_unlocks;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.add_permanent_unlock(UUID, TEXT) TO authenticated;

-- STEP 5: Verification query (for testing)
-- ───────────────────────────────────────────────────────────────────────────
-- Run this to verify the migration:
--
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'player_profiles'
--   AND column_name IN ('membership_tier', 'shards_balance', 'permanent_unlocks');
--
-- Expected output:
-- | column_name       | data_type | column_default |
-- |-------------------|-----------|----------------|
-- | membership_tier   | integer   | 0              |
-- | shards_balance    | integer   | 0              |
-- | permanent_unlocks | ARRAY     | '{}'::text[]   |
