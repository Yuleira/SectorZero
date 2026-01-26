-- =============================================
-- 交易系统数据库迁移
-- 版本: 007
-- 创建时间: 2026-01-26
-- 描述: 创建交易挂单表和交易历史表，支持玩家之间的异步物品交易
-- =============================================

-- =============================================
-- 1. 创建交易挂单表（trade_offers）
-- =============================================

CREATE TABLE IF NOT EXISTS trade_offers (
    -- 基本信息
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT,

    -- 交易内容（JSON 格式存储物品列表）
    -- 格式: [{"item_id": "wood", "quantity": 10}, ...]
    offering_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    requesting_items JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- 状态信息
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'expired')),
    message TEXT,

    -- 时间戳
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,

    -- 完成信息
    completed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_username TEXT,

    -- 约束
    CONSTRAINT valid_items CHECK (
        jsonb_array_length(offering_items) > 0 AND
        jsonb_array_length(requesting_items) > 0
    ),
    CONSTRAINT valid_expires_at CHECK (expires_at > created_at)
);

-- =============================================
-- 2. 创建交易历史表（trade_history）
-- =============================================

CREATE TABLE IF NOT EXISTS trade_history (
    -- 基本信息
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID REFERENCES trade_offers(id) ON DELETE SET NULL,

    -- 交易双方
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_username TEXT,
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    buyer_username TEXT,

    -- 交换的物品详情（JSON 格式）
    -- 格式: {"offered": [...], "requested": [...]}
    items_exchanged JSONB NOT NULL,

    -- 时间戳
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- 评价信息
    seller_rating INTEGER CHECK (seller_rating >= 1 AND seller_rating <= 5),
    buyer_rating INTEGER CHECK (buyer_rating >= 1 AND buyer_rating <= 5),
    seller_comment TEXT,
    buyer_comment TEXT,

    -- 约束
    CONSTRAINT different_users CHECK (seller_id != buyer_id)
);

-- =============================================
-- 3. 创建索引（提升查询性能）
-- =============================================

-- trade_offers 表索引
CREATE INDEX IF NOT EXISTS idx_trade_offers_owner ON trade_offers(owner_id);
CREATE INDEX IF NOT EXISTS idx_trade_offers_status ON trade_offers(status);
CREATE INDEX IF NOT EXISTS idx_trade_offers_expires_at ON trade_offers(expires_at);
CREATE INDEX IF NOT EXISTS idx_trade_offers_created_at ON trade_offers(created_at DESC);

-- 复合索引：查询活跃且未过期的挂单
CREATE INDEX IF NOT EXISTS idx_trade_offers_active_not_expired
ON trade_offers(status, expires_at)
WHERE status = 'active';

-- trade_history 表索引
CREATE INDEX IF NOT EXISTS idx_trade_history_seller ON trade_history(seller_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_buyer ON trade_history(buyer_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_offer ON trade_history(offer_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_completed_at ON trade_history(completed_at DESC);

-- =============================================
-- 4. 行级安全策略（RLS）
-- =============================================

-- 启用 RLS
ALTER TABLE trade_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_history ENABLE ROW LEVEL SECURITY;

-- trade_offers 策略

-- 所有已登录用户可以查看活跃的挂单
CREATE POLICY "Anyone can view active offers"
ON trade_offers FOR SELECT
TO authenticated
USING (status = 'active' OR owner_id = auth.uid());

-- 只有发布者可以查看自己的所有挂单
CREATE POLICY "Users can view their own offers"
ON trade_offers FOR SELECT
TO authenticated
USING (owner_id = auth.uid());

-- 用户可以创建自己的挂单
CREATE POLICY "Users can create their own offers"
ON trade_offers FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- 用户可以更新自己的挂单（仅限取消）
CREATE POLICY "Users can update their own offers"
ON trade_offers FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- trade_history 策略

-- 用户只能查看自己参与的交易历史
CREATE POLICY "Users can view their own trade history"
ON trade_history FOR SELECT
TO authenticated
USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 系统可以创建交易历史记录（通过函数调用）
CREATE POLICY "System can create trade history"
ON trade_history FOR INSERT
TO authenticated
WITH CHECK (true);

-- 用户可以更新自己参与的交易评价
CREATE POLICY "Users can update their trade ratings"
ON trade_history FOR UPDATE
TO authenticated
USING (seller_id = auth.uid() OR buyer_id = auth.uid())
WITH CHECK (seller_id = auth.uid() OR buyer_id = auth.uid());

-- =============================================
-- 5. 核心函数：创建交易挂单
-- =============================================

CREATE OR REPLACE FUNCTION create_trade_offer(
    p_offering_items JSONB,
    p_requesting_items JSONB,
    p_validity_hours INTEGER DEFAULT 24,
    p_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_offer_id UUID;
    v_item JSONB;
    v_available INTEGER;
BEGIN
    -- 1. 获取当前用户信息
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 获取用户名（从 profiles 表或 auth.users）
    SELECT email INTO v_username FROM auth.users WHERE id = v_user_id;

    -- 2. 验证提供的物品库存
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_offering_items)
    LOOP
        -- 获取用户库存中该物品的总数量
        SELECT COALESCE(SUM(quantity), 0)
        INTO v_available
        FROM inventory_items
        WHERE user_id = v_user_id
          AND item_definition_id = (v_item->>'item_id')::TEXT;

        -- 检查数量是否足够
        IF v_available < (v_item->>'quantity')::INTEGER THEN
            RAISE EXCEPTION 'Insufficient items: % (need %, have %)',
                v_item->>'item_id',
                (v_item->>'quantity')::INTEGER,
                v_available;
        END IF;
    END LOOP;

    -- 3. 锁定物品（从库存扣除）
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_offering_items)
    LOOP
        -- 使用 InventoryManager 的逻辑，按 FIFO 顺序扣除
        PERFORM remove_items_by_definition(
            v_user_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    -- 4. 创建挂单记录
    INSERT INTO trade_offers (
        owner_id,
        owner_username,
        offering_items,
        requesting_items,
        message,
        expires_at
    ) VALUES (
        v_user_id,
        v_username,
        p_offering_items,
        p_requesting_items,
        p_message,
        now() + (p_validity_hours || ' hours')::INTERVAL
    )
    RETURNING id INTO v_offer_id;

    RETURN v_offer_id;
END;
$$;

-- =============================================
-- 6. 核心函数：接受交易挂单
-- =============================================

CREATE OR REPLACE FUNCTION accept_trade_offer(
    p_offer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_offer RECORD;
    v_item JSONB;
    v_available INTEGER;
    v_history_id UUID;
BEGIN
    -- 1. 获取当前用户信息
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT email INTO v_username FROM auth.users WHERE id = v_user_id;

    -- 2. 查询并锁定挂单（行级锁，防止并发）
    SELECT * INTO v_offer
    FROM trade_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    -- 3. 验证挂单状态
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

    -- 4. 验证接受者库存
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
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

    -- 5. 执行物品交换

    -- 5a. 从接受者库存扣除"需要的物品"
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        PERFORM remove_items_by_definition(
            v_user_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    -- 5b. 向接受者库存添加"提供的物品"
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
    LOOP
        PERFORM add_item_to_inventory(
            v_user_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    -- 5c. 向发布者库存添加"需要的物品"
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        PERFORM add_item_to_inventory(
            v_offer.owner_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    -- 6. 更新挂单状态
    UPDATE trade_offers
    SET status = 'completed',
        completed_at = now(),
        completed_by_user_id = v_user_id,
        completed_by_username = v_username
    WHERE id = p_offer_id;

    -- 7. 创建交易历史记录
    INSERT INTO trade_history (
        offer_id,
        seller_id,
        seller_username,
        buyer_id,
        buyer_username,
        items_exchanged
    ) VALUES (
        p_offer_id,
        v_offer.owner_id,
        v_offer.owner_username,
        v_user_id,
        v_username,
        jsonb_build_object(
            'offered', v_offer.offering_items,
            'requested', v_offer.requesting_items
        )
    )
    RETURNING id INTO v_history_id;

    -- 8. 返回结果
    RETURN jsonb_build_object(
        'success', true,
        'history_id', v_history_id,
        'offered_items', v_offer.offering_items,
        'received_items', v_offer.requesting_items
    );
END;
$$;

-- =============================================
-- 7. 核心函数：取消交易挂单
-- =============================================

CREATE OR REPLACE FUNCTION cancel_trade_offer(
    p_offer_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_offer RECORD;
    v_item JSONB;
BEGIN
    -- 1. 获取当前用户信息
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. 查询挂单信息
    SELECT * INTO v_offer
    FROM trade_offers
    WHERE id = p_offer_id;

    -- 3. 验证权限
    IF v_offer IS NULL THEN
        RAISE EXCEPTION 'Trade offer not found';
    END IF;

    IF v_offer.owner_id != v_user_id THEN
        RAISE EXCEPTION 'You can only cancel your own trade offers';
    END IF;

    IF v_offer.status != 'active' THEN
        RAISE EXCEPTION 'Can only cancel active trade offers';
    END IF;

    -- 4. 退还物品
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
    LOOP
        PERFORM add_item_to_inventory(
            v_user_id,
            (v_item->>'item_id')::TEXT,
            (v_item->>'quantity')::INTEGER
        );
    END LOOP;

    -- 5. 更新挂单状态
    UPDATE trade_offers
    SET status = 'cancelled'
    WHERE id = p_offer_id;

    RETURN TRUE;
END;
$$;

-- =============================================
-- 8. 辅助函数：处理过期挂单
-- =============================================

CREATE OR REPLACE FUNCTION process_expired_offers()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer RECORD;
    v_item JSONB;
    v_count INTEGER := 0;
BEGIN
    -- 查询所有过期的活跃挂单
    FOR v_offer IN
        SELECT * FROM trade_offers
        WHERE status = 'active'
          AND expires_at < now()
    LOOP
        -- 退还物品
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
        LOOP
            PERFORM add_item_to_inventory(
                v_offer.owner_id,
                (v_item->>'item_id')::TEXT,
                (v_item->>'quantity')::INTEGER
            );
        END LOOP;

        -- 更新状态为 expired
        UPDATE trade_offers
        SET status = 'expired'
        WHERE id = v_offer.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

-- =============================================
-- 9. 评价交易函数
-- =============================================

CREATE OR REPLACE FUNCTION rate_trade(
    p_trade_history_id UUID,
    p_rating INTEGER,
    p_comment TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_trade RECORD;
BEGIN
    -- 1. 获取当前用户信息
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. 查询交易历史记录
    SELECT * INTO v_trade
    FROM trade_history
    WHERE id = p_trade_history_id;

    IF v_trade IS NULL THEN
        RAISE EXCEPTION 'Trade history not found';
    END IF;

    -- 3. 验证权限并更新评价
    IF v_trade.seller_id = v_user_id THEN
        -- 卖家评价买家
        IF v_trade.seller_rating IS NOT NULL THEN
            RAISE EXCEPTION 'You have already rated this trade';
        END IF;

        UPDATE trade_history
        SET seller_rating = p_rating,
            seller_comment = p_comment
        WHERE id = p_trade_history_id;

    ELSIF v_trade.buyer_id = v_user_id THEN
        -- 买家评价卖家
        IF v_trade.buyer_rating IS NOT NULL THEN
            RAISE EXCEPTION 'You have already rated this trade';
        END IF;

        UPDATE trade_history
        SET buyer_rating = p_rating,
            buyer_comment = p_comment
        WHERE id = p_trade_history_id;

    ELSE
        RAISE EXCEPTION 'You are not a participant in this trade';
    END IF;

    RETURN TRUE;
END;
$$;

-- =============================================
-- 10. 查询函数（辅助）
-- =============================================

-- 获取可接受的挂单（活跃且未过期，排除自己的）
CREATE OR REPLACE FUNCTION get_available_trade_offers(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS SETOF trade_offers
LANGUAGE sql
SECURITY DEFINER
STABLE
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

-- 获取我的挂单
CREATE OR REPLACE FUNCTION get_my_trade_offers(
    p_status TEXT DEFAULT NULL
)
RETURNS SETOF trade_offers
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT *
    FROM trade_offers
    WHERE owner_id = auth.uid()
      AND (p_status IS NULL OR status = p_status)
    ORDER BY created_at DESC;
$$;

-- 获取交易历史
CREATE OR REPLACE FUNCTION get_my_trade_history()
RETURNS SETOF trade_history
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT *
    FROM trade_history
    WHERE seller_id = auth.uid()
       OR buyer_id = auth.uid()
    ORDER BY completed_at DESC;
$$;

-- =============================================
-- 完成迁移
-- =============================================

COMMENT ON TABLE trade_offers IS '交易挂单表：存储玩家发布的交易请求';
COMMENT ON TABLE trade_history IS '交易历史表：记录已完成的交易';
COMMENT ON FUNCTION create_trade_offer IS '创建交易挂单，自动锁定物品';
COMMENT ON FUNCTION accept_trade_offer IS '接受交易挂单，执行物品交换';
COMMENT ON FUNCTION cancel_trade_offer IS '取消交易挂单，退还物品';
COMMENT ON FUNCTION process_expired_offers IS '处理过期挂单，定时任务调用';
COMMENT ON FUNCTION rate_trade IS '评价交易';
