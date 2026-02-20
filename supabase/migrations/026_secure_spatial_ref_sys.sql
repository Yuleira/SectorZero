-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 026: Secure public.spatial_ref_sys (PostGIS Reference Table)
-- ═══════════════════════════════════════════════════════════════════════════
--
-- WHY THIS CANNOT RUN VIA db push:
--   spatial_ref_sys is owned by the supabase_admin role (installed by PostGIS
--   extension). The migration runner connects as postgres, which is NOT the
--   owner and receives SQLSTATE 42501 (insufficient_privilege) on ALTER TABLE.
--
-- ACTION REQUIRED — paste the four lines below into the Supabase Dashboard
-- SQL Editor (Project Settings → SQL Editor → New query) and click Run:
--
--   ALTER TABLE "public"."spatial_ref_sys" ENABLE ROW LEVEL SECURITY;
--
--   DROP POLICY IF EXISTS "allow_select_for_authenticated"
--     ON "public"."spatial_ref_sys";
--
--   CREATE POLICY "allow_select_for_authenticated"
--     ON "public"."spatial_ref_sys"
--     FOR SELECT TO authenticated USING (true);
--
--   REVOKE INSERT, UPDATE, DELETE
--     ON "public"."spatial_ref_sys"
--     FROM PUBLIC, authenticated, anon;
--
-- The DO block below attempts the same statements programmatically and
-- catches the privilege error so this migration file does not block
-- future `supabase db push` runs.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    ALTER TABLE "public"."spatial_ref_sys" ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "allow_select_for_authenticated"
        ON "public"."spatial_ref_sys";

    CREATE POLICY "allow_select_for_authenticated"
        ON "public"."spatial_ref_sys"
        FOR SELECT TO authenticated
        USING (true);

    REVOKE INSERT, UPDATE, DELETE
        ON "public"."spatial_ref_sys"
        FROM PUBLIC, authenticated, anon;

    RAISE NOTICE 'Migration 026: spatial_ref_sys secured via migration runner.';
EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE NOTICE 'Migration 026: postgres role cannot alter spatial_ref_sys (owned by supabase_admin). Apply the four SQL statements manually in the Supabase Dashboard SQL Editor.';
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
