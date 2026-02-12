-- Migration 020: Add distance tracking columns
-- territories.distance_walked: per-territory walking distance (meters)
-- player_profiles.total_distance_walked: cumulative lifetime walking distance (meters)

ALTER TABLE territories
  ADD COLUMN IF NOT EXISTS distance_walked DOUBLE PRECISION DEFAULT 0;

ALTER TABLE player_profiles
  ADD COLUMN IF NOT EXISTS total_distance_walked DOUBLE PRECISION DEFAULT 0;
