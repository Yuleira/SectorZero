-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 018_add_aether_energy.sql
-- Description: Add Aether Energy column to player_profiles for AI scan gating
-- ═══════════════════════════════════════════════════════════════════════════

-- STEP 1: Add aether_energy column with 5 free scans for new players
-- ───────────────────────────────────────────────────────────────────────────

ALTER TABLE public.player_profiles
ADD COLUMN IF NOT EXISTS aether_energy INTEGER DEFAULT 5;

COMMENT ON COLUMN public.player_profiles.aether_energy IS
    'Aether Energy balance — consumed per AI scan. Default 5 free scans for new players. Archon tier gets unlimited.';

-- STEP 2: Set existing players to 5 free scans if null
-- ───────────────────────────────────────────────────────────────────────────

UPDATE public.player_profiles
SET aether_energy = 5
WHERE aether_energy IS NULL;

-- STEP 3: Verification query
-- ───────────────────────────────────────────────────────────────────────────
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'player_profiles'
--   AND column_name = 'aether_energy';
--
-- Expected: aether_energy | integer | 5
