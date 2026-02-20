-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 027: Fix trade_history INSERT policy (correct policy name)
-- ═══════════════════════════════════════════════════════════════════════════
--
-- WHY: Migration 023 created an INSERT policy named "System can create trade
-- history" with WITH CHECK (true) — allowing any authenticated user to insert
-- any trade record regardless of whether they are the buyer or seller.
--
-- Migration 025 attempted to fix this but used the wrong policy name
-- ("trade_history_insert") — that DROP was a silent no-op, leaving the
-- permissive policy intact and still flagged by the Supabase Advisor.
--
-- FIX: Drop the correctly-named policy and recreate it with a proper check.
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop the permissive policy (name from migration 023 line 41)
DROP POLICY IF EXISTS "System can create trade history" ON public.trade_history;

-- Also clean up the misnamed attempt from migration 025 (no-op if absent)
DROP POLICY IF EXISTS "trade_history_insert" ON public.trade_history;

-- Recreate with a secure check: only the buyer or seller may insert the record
CREATE POLICY "System can create trade history"
    ON public.trade_history
    FOR INSERT
    TO authenticated
    WITH CHECK (buyer_id = auth.uid() OR seller_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
