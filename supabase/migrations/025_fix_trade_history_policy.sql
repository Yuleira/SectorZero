-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 025: Fix trade_history INSERT Policy — Remove "Always True"
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ROOT CAUSE: Migration 007 created the trade_history INSERT policy with
-- `WITH CHECK (true)`, which Supabase Advisor flags as "Always True" because
-- it allows any authenticated user to insert rows for any buyer/seller pair.
--
-- FIX: Replace `WITH CHECK (true)` with
-- `WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid())`
-- so only the buyer or seller involved in a trade can record its history.
--

-- Drop the permissive policy created in migration 007
DROP POLICY IF EXISTS "trade_history_insert" ON trade_history;

-- Re-create with tighter check
CREATE POLICY "trade_history_insert" ON trade_history
    FOR INSERT
    WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
