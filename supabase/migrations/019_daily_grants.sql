-- Migration 019: Add daily grant tracking columns
-- Used to track last daily energy and coin grant dates,
-- preventing duplicate grants within the same day.

ALTER TABLE public.player_profiles
ADD COLUMN IF NOT EXISTS last_energy_grant_date DATE,
ADD COLUMN IF NOT EXISTS last_coin_grant_date DATE;
