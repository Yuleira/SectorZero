-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 023: Fix Supabase Security Advisor Warnings & Error
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Fixes:
--   1 Error   → Enable RLS on trade_offers + trade_history (migration 007
--               had no semicolons, so ALTER TABLE ... ENABLE ROW LEVEL SECURITY
--               may never have executed)
--   25 Warnings → Add SET search_path = public to every SECURITY DEFINER
--               function that lacked it (prevents search_path injection)
--
-- Execute: Supabase Dashboard → SQL Editor, or supabase db push

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: Fix the 1 Error — ensure RLS is ON for trade tables
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE IF EXISTS public.trade_offers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.trade_history ENABLE ROW LEVEL SECURITY;

-- Ensure policies exist (idempotent DROP + CREATE)
DROP POLICY IF EXISTS "Anyone can view active offers"           ON public.trade_offers;
DROP POLICY IF EXISTS "Users can view their own offers"        ON public.trade_offers;
DROP POLICY IF EXISTS "Users can create their own offers"      ON public.trade_offers;
DROP POLICY IF EXISTS "Users can update their own offers"      ON public.trade_offers;

CREATE POLICY "Anyone can view active offers"
    ON public.trade_offers FOR SELECT TO authenticated
    USING (status = 'active' OR owner_id = auth.uid());

CREATE POLICY "Users can create their own offers"
    ON public.trade_offers FOR INSERT TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own offers"
    ON public.trade_offers FOR UPDATE TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own trade history"  ON public.trade_history;
DROP POLICY IF EXISTS "System can create trade history"         ON public.trade_history;
DROP POLICY IF EXISTS "Users can update their trade ratings"    ON public.trade_history;

CREATE POLICY "Users can view their own trade history"
    ON public.trade_history FOR SELECT TO authenticated
    USING (seller_id = auth.uid() OR buyer_id = auth.uid());

CREATE POLICY "System can create trade history"
    ON public.trade_history FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users can update their trade ratings"
    ON public.trade_history FOR UPDATE TO authenticated
    USING (seller_id = auth.uid() OR buyer_id = auth.uid())
    WITH CHECK (seller_id = auth.uid() OR buyer_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: Fix 25 Warnings — add SET search_path = public to all functions
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 001: handle_new_user ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$;

-- ── 003: update_inventory_timestamp ─────────────────────────────────────

CREATE OR REPLACE FUNCTION update_inventory_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ── 005: update_buildings_timestamp ─────────────────────────────────────

CREATE OR REPLACE FUNCTION update_buildings_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ── 007: create_trade_offer ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_trade_offer(
    p_offering_items JSONB,
    p_requesting_items JSONB,
    p_validity_hours INTEGER DEFAULT 24,
    p_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_offer_id UUID;
    v_item JSONB;
    v_available INTEGER;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO v_username FROM auth.users WHERE id = v_user_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_offering_items)
    LOOP
        SELECT COALESCE(SUM(quantity), 0)
        INTO v_available
        FROM inventory_items
        WHERE user_id = v_user_id
          AND item_definition_id = (v_item->>'item_id')::TEXT;

        IF v_available < (v_item->>'quantity')::INTEGER THEN
            RAISE EXCEPTION 'Insufficient items: % (need %, have %)',
                v_item->>'item_id',
                (v_item->>'quantity')::INTEGER,
                v_available;
        END IF;
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_offering_items)
    LOOP
        PERFORM remove_items_by_definition(
            v_user_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    INSERT INTO trade_offers (
        owner_id, owner_username, offering_items, requesting_items, message, expires_at
    ) VALUES (
        v_user_id, v_username, p_offering_items, p_requesting_items, p_message,
        now() + (p_validity_hours || ' hours')::INTERVAL
    )
    RETURNING id INTO v_offer_id;

    RETURN v_offer_id;
END;
$$;

-- ── 007: accept_trade_offer ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION accept_trade_offer(p_offer_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_offer RECORD;
    v_item JSONB;
    v_available INTEGER;
    v_history_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO v_username FROM auth.users WHERE id = v_user_id;

    SELECT * INTO v_offer FROM trade_offers WHERE id = p_offer_id FOR UPDATE;

    IF v_offer IS NULL THEN
        RAISE EXCEPTION 'Trade offer not found';
    END IF;
    IF v_offer.status != 'active' THEN
        RAISE EXCEPTION 'Trade offer is not active (status: %)', v_offer.status;
    END IF;
    IF v_offer.expires_at < now() THEN
        RAISE EXCEPTION 'Trade offer has expired';
    END IF;
    IF v_offer.owner_id = v_user_id THEN
        RAISE EXCEPTION 'Cannot accept your own trade offer';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        SELECT COALESCE(SUM(quantity), 0)
        INTO v_available
        FROM inventory_items
        WHERE user_id = v_user_id
          AND item_definition_id = (v_item->>'item_id')::TEXT;

        IF v_available < (v_item->>'quantity')::INTEGER THEN
            RAISE EXCEPTION 'Insufficient items: % (need %, have %)',
                v_item->>'item_id', (v_item->>'quantity')::INTEGER, v_available;
        END IF;
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        PERFORM remove_items_by_definition(v_user_id, (v_item->>'item_id')::TEXT, (v_item->>'quantity')::INTEGER);
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
    LOOP
        PERFORM add_item_to_inventory(v_user_id, (v_item->>'item_id')::TEXT, (v_item->>'quantity')::INTEGER);
    END LOOP;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        PERFORM add_item_to_inventory(v_offer.owner_id, (v_item->>'item_id')::TEXT, (v_item->>'quantity')::INTEGER);
    END LOOP;

    UPDATE trade_offers
    SET status = 'completed', completed_at = now(),
        completed_by_user_id = v_user_id, completed_by_username = v_username
    WHERE id = p_offer_id;

    INSERT INTO trade_history (
        offer_id, seller_id, seller_username, buyer_id, buyer_username, items_exchanged
    ) VALUES (
        p_offer_id, v_offer.owner_id, v_offer.owner_username, v_user_id, v_username,
        jsonb_build_object('offered', v_offer.offering_items, 'requested', v_offer.requesting_items)
    )
    RETURNING id INTO v_history_id;

    RETURN jsonb_build_object(
        'success', true, 'history_id', v_history_id,
        'offered_items', v_offer.offering_items, 'received_items', v_offer.requesting_items
    );
END;
$$;

-- ── 007: cancel_trade_offer ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION cancel_trade_offer(p_offer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_offer RECORD;
    v_item JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_offer FROM trade_offers WHERE id = p_offer_id;

    IF v_offer IS NULL THEN
        RAISE EXCEPTION 'Trade offer not found';
    END IF;
    IF v_offer.owner_id != v_user_id THEN
        RAISE EXCEPTION 'You can only cancel your own trade offers';
    END IF;
    IF v_offer.status != 'active' THEN
        RAISE EXCEPTION 'Can only cancel active trade offers';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
    LOOP
        PERFORM add_item_to_inventory(v_user_id, (v_item->>'item_id')::TEXT, (v_item->>'quantity')::INTEGER);
    END LOOP;

    UPDATE trade_offers SET status = 'cancelled' WHERE id = p_offer_id;

    RETURN TRUE;
END;
$$;

-- ── 007: process_expired_offers ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION process_expired_offers()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_offer RECORD;
    v_item JSONB;
    v_count INTEGER := 0;
BEGIN
    FOR v_offer IN
        SELECT * FROM trade_offers WHERE status = 'active' AND expires_at < now()
    LOOP
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
        LOOP
            PERFORM add_item_to_inventory(v_offer.owner_id, (v_item->>'item_id')::TEXT, (v_item->>'quantity')::INTEGER);
        END LOOP;

        UPDATE trade_offers SET status = 'expired' WHERE id = v_offer.id;
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

-- ── 007: rate_trade ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION rate_trade(
    p_trade_history_id UUID,
    p_rating INTEGER,
    p_comment TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_trade RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_trade FROM trade_history WHERE id = p_trade_history_id;

    IF v_trade IS NULL THEN
        RAISE EXCEPTION 'Trade history not found';
    END IF;

    IF v_trade.seller_id = v_user_id THEN
        IF v_trade.seller_rating IS NOT NULL THEN
            RAISE EXCEPTION 'You have already rated this trade';
        END IF;
        UPDATE trade_history SET seller_rating = p_rating, seller_comment = p_comment
        WHERE id = p_trade_history_id;
    ELSIF v_trade.buyer_id = v_user_id THEN
        IF v_trade.buyer_rating IS NOT NULL THEN
            RAISE EXCEPTION 'You have already rated this trade';
        END IF;
        UPDATE trade_history SET buyer_rating = p_rating, buyer_comment = p_comment
        WHERE id = p_trade_history_id;
    ELSE
        RAISE EXCEPTION 'You are not a participant in this trade';
    END IF;

    RETURN TRUE;
END;
$$;

-- ── 007: get_available_trade_offers (sql) ────────────────────────────────

CREATE OR REPLACE FUNCTION get_available_trade_offers(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS SETOF trade_offers
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT *
    FROM trade_offers
    WHERE status = 'active'
      AND expires_at > now()
      AND owner_id != auth.uid()
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

-- ── 007: get_my_trade_offers (sql) ───────────────────────────────────────

CREATE OR REPLACE FUNCTION get_my_trade_offers(p_status TEXT DEFAULT NULL)
RETURNS SETOF trade_offers
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT *
    FROM trade_offers
    WHERE owner_id = auth.uid()
      AND (p_status IS NULL OR status = p_status)
    ORDER BY created_at DESC;
$$;

-- ── 007: get_my_trade_history (sql) ──────────────────────────────────────

CREATE OR REPLACE FUNCTION get_my_trade_history()
RETURNS SETOF trade_history
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT *
    FROM trade_history
    WHERE seller_id = auth.uid()
       OR buyer_id = auth.uid()
    ORDER BY completed_at DESC;
$$;

-- ── 008: remove_items_by_definition ─────────────────────────────────────

CREATE OR REPLACE FUNCTION remove_items_by_definition(
    p_user_id UUID,
    p_item_definition_id TEXT,
    p_quantity INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item RECORD;
    v_remaining INTEGER := p_quantity;
    v_to_remove INTEGER;
BEGIN
    IF p_user_id IS NULL OR p_item_definition_id IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid parameters';
    END IF;

    FOR v_item IN
        SELECT id, quantity, quality
        FROM inventory_items
        WHERE user_id = p_user_id
          AND LOWER(item_definition_id) = LOWER(p_item_definition_id)
        ORDER BY
            CASE quality
                WHEN 'ruined'   THEN 1
                WHEN 'damaged'  THEN 2
                WHEN 'worn'     THEN 3
                WHEN 'good'     THEN 4
                WHEN 'pristine' THEN 5
                ELSE 6
            END,
            acquired_at ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining <= 0;
        v_to_remove := LEAST(v_remaining, v_item.quantity);

        IF v_item.quantity <= v_to_remove THEN
            DELETE FROM inventory_items WHERE id = v_item.id;
        ELSE
            UPDATE inventory_items SET quantity = quantity - v_to_remove WHERE id = v_item.id;
        END IF;

        v_remaining := v_remaining - v_to_remove;
    END LOOP;

    IF v_remaining > 0 THEN
        RAISE EXCEPTION 'Insufficient items: % (needed %, short %)',
            p_item_definition_id, p_quantity, v_remaining;
    END IF;

    RETURN TRUE;
END;
$$;

-- ── 008: add_item_to_inventory ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION add_item_to_inventory(
    p_user_id UUID,
    p_item_definition_id TEXT,
    p_quantity INTEGER,
    p_quality TEXT DEFAULT 'good',
    p_rarity TEXT DEFAULT 'common',
    p_source TEXT DEFAULT 'trade'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item_id UUID;
    v_existing_item RECORD;
BEGIN
    IF p_user_id IS NULL OR p_item_definition_id IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid parameters';
    END IF;
    IF p_quality NOT IN ('pristine', 'good', 'worn', 'damaged', 'ruined') THEN
        RAISE EXCEPTION 'Invalid quality: %', p_quality;
    END IF;

    SELECT id, quantity INTO v_existing_item
    FROM inventory_items
    WHERE user_id = p_user_id
      AND LOWER(item_definition_id) = LOWER(p_item_definition_id)
      AND quality = p_quality
    ORDER BY acquired_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_existing_item IS NOT NULL THEN
        UPDATE inventory_items SET quantity = quantity + p_quantity WHERE id = v_existing_item.id;
        v_item_id := v_existing_item.id;
    ELSE
        INSERT INTO inventory_items (
            user_id, item_definition_id, quantity, quality, source_type, acquired_at
        ) VALUES (
            p_user_id, LOWER(p_item_definition_id), p_quantity, p_quality, p_source, now()
        )
        RETURNING id INTO v_item_id;
    END IF;

    RETURN v_item_id;
END;
$$;

-- ── 009: initialize_user_devices ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION initialize_user_devices(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.communication_devices (user_id, device_type, is_unlocked, is_current)
    VALUES
        (p_user_id, 'radio',        true,  false),
        (p_user_id, 'walkie_talkie',true,  true),
        (p_user_id, 'camp_radio',   false, false),
        (p_user_id, 'satellite',    false, false)
    ON CONFLICT (user_id, device_type) DO NOTHING;
END;
$$;

-- ── 009: switch_current_device ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION switch_current_device(p_user_id UUID, p_device_type TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.communication_devices
        WHERE user_id = p_user_id AND device_type = p_device_type AND is_unlocked = true
    ) THEN
        RAISE EXCEPTION '设备未解锁';
    END IF;

    UPDATE public.communication_devices SET is_current = false WHERE user_id = p_user_id;
    UPDATE public.communication_devices SET is_current = true
    WHERE user_id = p_user_id AND device_type = p_device_type;

    RETURN true;
END;
$$;

-- ── 010: generate_channel_code ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_channel_code(p_channel_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_prefix TEXT;
    v_random TEXT;
    v_code TEXT;
    v_exists BOOLEAN;
BEGIN
    CASE p_channel_type
        WHEN 'official'  THEN v_prefix := 'OFF-';
        WHEN 'public'    THEN v_prefix := 'PUB-';
        WHEN 'walkie'    THEN v_prefix := '438.';
        WHEN 'camp'      THEN v_prefix := 'CAMP-';
        WHEN 'satellite' THEN v_prefix := 'SAT-';
        ELSE v_prefix := 'CH-';
    END CASE;

    LOOP
        IF p_channel_type = 'walkie' THEN
            v_random := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
        ELSE
            v_random := UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6));
        END IF;

        v_code := v_prefix || v_random;

        SELECT EXISTS(
            SELECT 1 FROM public.communication_channels WHERE channel_code = v_code
        ) INTO v_exists;

        EXIT WHEN NOT v_exists;
    END LOOP;

    RETURN v_code;
END;
$$;

-- ── 010: create_channel_with_subscription ────────────────────────────────

CREATE OR REPLACE FUNCTION create_channel_with_subscription(
    p_creator_id UUID,
    p_channel_type TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_channel_id UUID;
    v_channel_code TEXT;
BEGIN
    v_channel_code := generate_channel_code(p_channel_type);

    INSERT INTO public.communication_channels (
        creator_id, channel_type, channel_code, name, description, member_count
    ) VALUES (
        p_creator_id, p_channel_type, v_channel_code, p_name, p_description, 1
    ) RETURNING id INTO v_channel_id;

    INSERT INTO public.channel_subscriptions (user_id, channel_id)
    VALUES (p_creator_id, v_channel_id);

    RETURN v_channel_id;
END;
$$;

-- ── 010: subscribe_to_channel ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION subscribe_to_channel(p_channel_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF NOT EXISTS (
        SELECT 1 FROM public.communication_channels
        WHERE id = p_channel_id AND is_active = true
    ) THEN
        RAISE EXCEPTION '频道不存在或已关闭';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE user_id = v_user_id AND channel_id = p_channel_id
    ) THEN
        RETURN true;
    END IF;

    INSERT INTO public.channel_subscriptions (user_id, channel_id)
    VALUES (v_user_id, p_channel_id);

    UPDATE public.communication_channels
    SET member_count = member_count + 1, updated_at = now()
    WHERE id = p_channel_id;

    RETURN true;
END;
$$;

-- ── 010: unsubscribe_from_channel ────────────────────────────────────────

CREATE OR REPLACE FUNCTION unsubscribe_from_channel(p_channel_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_creator_id UUID;
BEGIN
    v_user_id := auth.uid();

    SELECT creator_id INTO v_creator_id
    FROM public.communication_channels WHERE id = p_channel_id;

    IF v_user_id = v_creator_id THEN
        RAISE EXCEPTION '频道创建者不能取消订阅';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE user_id = v_user_id AND channel_id = p_channel_id
    ) THEN
        RETURN true;
    END IF;

    DELETE FROM public.channel_subscriptions
    WHERE user_id = v_user_id AND channel_id = p_channel_id;

    UPDATE public.communication_channels
    SET member_count = GREATEST(member_count - 1, 1), updated_at = now()
    WHERE id = p_channel_id;

    RETURN true;
END;
$$;

-- ── 010: delete_channel ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION delete_channel(p_channel_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_creator_id UUID;
BEGIN
    v_user_id := auth.uid();

    SELECT creator_id INTO v_creator_id
    FROM public.communication_channels WHERE id = p_channel_id;

    IF v_user_id != v_creator_id THEN
        RAISE EXCEPTION '只有频道创建者可以删除频道';
    END IF;

    DELETE FROM public.channel_subscriptions WHERE channel_id = p_channel_id;
    DELETE FROM public.communication_channels WHERE id = p_channel_id;

    RETURN true;
END;
$$;

-- ── 013/015: send_channel_message (final version — uses player_profiles) ─

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
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_callsign TEXT;
    v_message_id UUID;
    v_point GEOMETRY(POINT, 4326);
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check subscription
    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'You must subscribe to send messages';
    END IF;

    -- Get callsign from player_profiles (Day 36 standardized table)
    BEGIN
        SELECT COALESCE(callsign, 'Anonymous')
        INTO v_callsign
        FROM public.player_profiles
        WHERE user_id = v_user_id;
    EXCEPTION
        WHEN undefined_table THEN v_callsign := 'Anonymous';
        WHEN no_data_found   THEN v_callsign := 'Anonymous';
    END;

    IF v_callsign IS NULL THEN
        v_callsign := 'Anonymous';
    END IF;

    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    END IF;

    INSERT INTO channel_messages (
        channel_id, sender_id, sender_callsign, content,
        sender_location, sender_latitude, sender_longitude, metadata
    ) VALUES (
        p_channel_id, v_user_id, v_callsign, p_content,
        v_point, p_latitude, p_longitude,
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

GRANT EXECUTE ON FUNCTION send_channel_message(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) TO authenticated;

-- ── 015: update_player_profiles_updated_at ───────────────────────────────

CREATE OR REPLACE FUNCTION update_player_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- ── 022: increment_distance_walked ───────────────────────────────────────

CREATE OR REPLACE FUNCTION increment_distance_walked(
    p_user_id UUID,
    p_delta DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE player_profiles
    SET total_distance_walked = COALESCE(total_distance_walked, 0) + p_delta,
        updated_at = NOW()
    WHERE user_id = p_user_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Verification: run the following to confirm zero remaining warnings
-- SELECT routine_name, security_type
-- FROM information_schema.routines
-- WHERE routine_schema = 'public'
--   AND routine_type = 'FUNCTION'
-- ORDER BY routine_name;
-- ═══════════════════════════════════════════════════════════════════════════
