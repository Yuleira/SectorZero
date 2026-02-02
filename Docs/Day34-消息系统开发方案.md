# Day 34：消息系统 - 完整开发方案

> 第34天开发内容：消息发送、实时推送、聊天界面
> **最后更新：包含踩坑记录和修复方案**

---

## 一、功能概览

### 1.1 核心功能清单

| 模块 | 功能 | 状态 |
|------|------|------|
| **数据库** | channel_messages 表 + RLS | 待完成 |
| **数据库** | send_channel_message RPC函数 | 待完成 |
| **数据库** | Realtime Publication 配置 | 待完成 |
| **Models** | ChannelMessage、LocationPoint、MessageMetadata | 待完成 |
| **Manager** | 消息加载 + 发送 + Realtime订阅 | 待完成 |
| **聊天界面** | ChannelChatView + MessageBubbleView | 待完成 |

### 1.2 与 Day 33 的关系

| Day 33 完成的 | Day 34 要做的 |
|--------------|--------------|
| 频道创建与订阅 | 消息发送与接收 |
| CommunicationManager 频道方法 | 扩展消息方法 + Realtime |
| CommunicationModels（频道相关） | 扩展消息相关模型 |
| ChannelCenterView + ChannelDetailView | ChannelChatView + MessageBubbleView |

---

## 二、文件清单

### 2.1 需要创建/扩展的文件

| 文件 | 路径 | 说明 |
|------|------|------|
| - | `Models/CommunicationModels.swift` | 扩展（添加消息相关模型） |
| - | `Managers/CommunicationManager.swift` | 扩展（添加消息方法 + Realtime） |
| `ChannelChatView.swift` | `Views/Communication/` | 聊天界面（新建或重写） |

### 2.2 数据库迁移

| 迁移名称 | 说明 |
|----------|------|
| `create_channel_messages_table` | 消息表 + RLS + 索引 + Publication |
| `create_send_message_function` | RPC函数（发送消息） |

---

## 三、数据库设计

### 3.1 channel_messages 表结构

| 字段 | 类型 | 说明 |
|------|------|------|
| message_id | UUID | 主键 |
| channel_id | UUID | 所属频道，外键 |
| sender_id | UUID | 发送者ID，外键关联 auth.users |
| sender_callsign | TEXT | 发送者呼号（显示用） |
| content | TEXT | 消息内容（必填） |
| sender_location | GEOGRAPHY(POINT, 4326) | 发送者位置（Day 35 距离过滤用） |
| metadata | JSONB | 额外信息（存 device_type） |
| created_at | TIMESTAMPTZ | 发送时间 |

### 3.2 RLS 策略

| 操作 | 策略 | 条件 |
|------|------|------|
| SELECT | 订阅者可查看 | 用户已订阅该频道 |
| INSERT | 订阅者可发送 | sender_id = auth.uid() 且已订阅 |

### 3.3 完整 SQL

```sql
-- 启用 PostGIS 扩展（如果尚未启用）
CREATE EXTENSION IF NOT EXISTS postgis;

-- 创建消息表
CREATE TABLE IF NOT EXISTS public.channel_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.communication_channels(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    sender_callsign TEXT,
    content TEXT NOT NULL,
    sender_location GEOGRAPHY(POINT, 4326),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 启用 RLS
ALTER TABLE public.channel_messages ENABLE ROW LEVEL SECURITY;

-- RLS 策略：订阅者可以查看频道消息
CREATE POLICY "订阅者可以查看频道消息" ON public.channel_messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
            AND channel_subscriptions.user_id = auth.uid()
        )
    );

-- RLS 策略：订阅者可以发送消息
CREATE POLICY "订阅者可以发送消息" ON public.channel_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
            AND channel_subscriptions.user_id = auth.uid()
        )
    );

-- 索引
CREATE INDEX idx_messages_channel ON public.channel_messages(channel_id);
CREATE INDEX idx_messages_sender ON public.channel_messages(sender_id);
CREATE INDEX idx_messages_created ON public.channel_messages(created_at DESC);

-- ⚠️ 启用 Realtime Publication（必须！否则 Realtime 订阅无法收到消息）
ALTER PUBLICATION supabase_realtime ADD TABLE channel_messages;
```

### 3.4 RPC 函数：send_channel_message

```sql
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id UUID,
    p_content TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID;
    v_sender_id UUID;
    v_callsign TEXT;
    v_location GEOGRAPHY(POINT, 4326);
    v_metadata JSONB;
BEGIN
    -- 获取当前用户 ID
    v_sender_id := auth.uid();

    -- 检查是否已订阅该频道
    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION '您未订阅此频道，无法发送消息';
    END IF;

    -- 获取用户呼号（如果有 user_profiles 表）
    BEGIN
        SELECT callsign INTO v_callsign
        FROM public.user_profiles
        WHERE user_id = v_sender_id;
    EXCEPTION
        WHEN undefined_table THEN
            v_callsign := NULL;
    END;

    -- 如果没有呼号，使用默认值
    IF v_callsign IS NULL THEN
        v_callsign := '匿名用户';
    END IF;

    -- 创建位置点（如果提供了坐标）
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    END IF;

    -- 构建 metadata
    v_metadata := jsonb_build_object('device_type', COALESCE(p_device_type, 'unknown'));

    -- 插入消息
    INSERT INTO public.channel_messages (
        channel_id, sender_id, sender_callsign, content, sender_location, metadata
    )
    VALUES (
        p_channel_id, v_sender_id, v_callsign, p_content, v_location, v_metadata
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 四、重要踩坑记录

### 4.1 Realtime Publication 未配置（最常见！）

#### 问题现象

Realtime 订阅成功启动，但永远收不到任何消息。

#### 根本原因

新创建的表默认不会被 Realtime 监听。

#### 解决方案

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE channel_messages;
```

#### 验证方法

```sql
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
-- 返回结果应包含 channel_messages
```

---

### 4.2 PostGIS POINT 格式解析

#### 问题现象

```
Fatal error: 'try!' expression unexpectedly raised an error
```

#### 根本原因

Supabase 返回的 PostGIS 格式是 WKT 字符串：`POINT(116.4074 39.9042)`，不是 JSON 对象。

#### 解决方案

自定义解码，支持字符串格式：

```swift
// 解析位置（可能是 PostGIS 格式或普通对象）
if let locationString = try? container.decode(String.self, forKey: .senderLocation) {
    senderLocation = LocationPoint.fromPostGIS(locationString)
} else {
    senderLocation = try container.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
}
```

---

### 4.3 日期格式解析失败

#### 问题现象

```
DecodingError: dataCorrupted
```

#### 根本原因

Supabase 返回的时间格式有多种可能，Swift 默认解码器不能处理。

#### 解决方案

多格式兼容解析：

```swift
// 解析日期（支持多种格式）
if let dateString = try? container.decode(String.self, forKey: .createdAt) {
    createdAt = ChannelMessage.parseDate(dateString) ?? Date()
} else {
    createdAt = try container.decode(Date.self, forKey: .createdAt)
}

private static func parseDate(_ string: String) -> Date? {
    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss"
    ]
    for format in formats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: string) {
            return date
        }
    }
    return nil
}
```

---

### 4.4 RealtimeChannelV2 找不到

#### 问题现象

```
Cannot find type 'RealtimeChannelV2' in scope
```

#### 根本原因

Supabase SDK 版本过旧。

#### 解决方案

更新 Supabase SDK 到最新版本：

```swift
// Package.swift 或 Xcode 包管理
.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
```

---

### 4.5 InsertAction 解码失败

#### 问题现象

```
Cannot decode ChannelMessage from InsertAction
```

#### 根本原因

需要使用正确的解码方法。

#### 解决方案

```swift
// ✅ 正确
let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: JSONDecoder())

// ❌ 错误
let message = try JSONDecoder().decode(ChannelMessage.self, from: insertion.record)
```

---

### 4.6 AuthManager.shared 不存在

#### 问题现象

```
Type 'AuthManager' has no member 'shared'
```

#### 根本原因

AuthManager 在此项目中不是单例模式。

#### 解决方案

```swift
// ❌ 错误
@ObservedObject private var authManager = AuthManager.shared

// ✅ 正确
@EnvironmentObject var authManager: AuthManager
```

---

### 4.7 ApocalypseTheme 属性名错误

#### 问题现象

```
Type 'ApocalypseTheme' has no member 'text'
```

#### 解决方案

| 错误写法 | 正确写法 |
|----------|----------|
| `ApocalypseTheme.text` | `ApocalypseTheme.textPrimary` |
| `ApocalypseTheme.secondaryText` | `ApocalypseTheme.textSecondary` |
| `ApocalypseTheme.accent` | `ApocalypseTheme.primary` |

---

## 五、Models 设计

### 5.1 ChannelMessage 结构体

```swift
// MARK: - 频道消息模型
struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
    }

    // 自定义解码（处理 PostGIS POINT 格式）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // 解析位置（可能是 PostGIS 格式或普通对象）
        if let locationString = try? container.decode(String.self, forKey: .senderLocation) {
            senderLocation = LocationPoint.fromPostGIS(locationString)
        } else {
            senderLocation = try container.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
        }

        // 解析日期（支持多种格式）
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    // 日期解析辅助方法
    private static func parseDate(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    // 显示用计算属性
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    // 获取设备类型
    var deviceType: String? {
        metadata?.deviceType
    }
}
```

### 5.2 LocationPoint 结构体

```swift
// MARK: - 位置点模型（用于解析 PostGIS POINT）
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    // 从 PostGIS WKT 格式解析：POINT(经度 纬度)
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        // 格式：POINT(121.4737 31.2304)
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}
```

### 5.3 MessageMetadata 结构体

```swift
// MARK: - 消息元数据
struct MessageMetadata: Codable {
    let deviceType: String?

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
    }
}
```

---

## 六、Manager 方法设计

### 6.1 消息相关属性

```swift
// MARK: - 消息相关属性
@Published var channelMessages: [UUID: [ChannelMessage]] = [:]  // 频道ID -> 消息列表
@Published var isSendingMessage = false

// MARK: - Realtime 相关属性
private var realtimeChannel: RealtimeChannelV2?
private var messageSubscriptionTask: Task<Void, Never>?
@Published var subscribedChannelIds: Set<UUID> = []
```

### 6.2 加载历史消息

```swift
/// 加载频道历史消息
func loadChannelMessages(channelId: UUID) async {
    do {
        let messages: [ChannelMessage] = try await supabase
            .from("channel_messages")
            .select()
            .eq("channel_id", value: channelId.uuidString)
            .order("created_at", ascending: true)
            .limit(50)
            .execute()
            .value

        await MainActor.run {
            channelMessages[channelId] = messages
        }
    } catch {
        await MainActor.run {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }
}
```

### 6.3 发送消息

```swift
/// 发送频道消息
func sendChannelMessage(
    channelId: UUID,
    content: String,
    latitude: Double? = nil,
    longitude: Double? = nil,
    deviceType: String? = nil
) async -> Bool {
    guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
        await MainActor.run {
            errorMessage = "消息内容不能为空"
        }
        return false
    }

    await MainActor.run {
        isSendingMessage = true
    }

    do {
        let params: [String: AnyJSON] = [
            "p_channel_id": .string(channelId.uuidString),
            "p_content": .string(content),
            "p_latitude": latitude.map { .double($0) } ?? .null,
            "p_longitude": longitude.map { .double($0) } ?? .null,
            "p_device_type": deviceType.map { .string($0) } ?? .null
        ]

        let _: UUID = try await supabase
            .rpc("send_channel_message", params: params)
            .execute()
            .value

        await MainActor.run {
            isSendingMessage = false
        }
        return true
    } catch {
        await MainActor.run {
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSendingMessage = false
        }
        return false
    }
}
```

### 6.4 Realtime 订阅

```swift
/// 启动 Realtime 消息订阅（统一订阅方案）
func startRealtimeSubscription() async {
    // 如果已经订阅，先停止
    await stopRealtimeSubscription()

    // 创建 Realtime 频道
    realtimeChannel = await supabase.realtimeV2.channel("channel_messages_realtime")

    guard let channel = realtimeChannel else { return }

    // 订阅 INSERT 事件
    let insertions = await channel.postgresChange(
        InsertAction.self,
        table: "channel_messages"
    )

    // 启动监听任务
    messageSubscriptionTask = Task { @MainActor [weak self] in
        for await insertion in insertions {
            await self?.handleNewMessage(insertion: insertion)
        }
    }

    // 开始订阅
    await channel.subscribe()

    print("[Realtime] 消息订阅已启动")
}

/// 停止 Realtime 订阅
func stopRealtimeSubscription() async {
    messageSubscriptionTask?.cancel()
    messageSubscriptionTask = nil

    if let channel = realtimeChannel {
        await channel.unsubscribe()
        realtimeChannel = nil
    }

    print("[Realtime] 消息订阅已停止")
}

/// 处理新消息
private func handleNewMessage(insertion: any PostgresAction) async {
    do {
        let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: JSONDecoder())

        // 检查是否是已订阅频道的消息
        guard subscribedChannelIds.contains(message.channelId) else {
            print("[Realtime] 忽略未订阅频道的消息: \(message.channelId)")
            return
        }

        // 添加到消息列表
        await MainActor.run {
            if channelMessages[message.channelId] != nil {
                channelMessages[message.channelId]?.append(message)
            } else {
                channelMessages[message.channelId] = [message]
            }
        }

        print("[Realtime] 收到新消息: \(message.content.prefix(20))...")
    } catch {
        print("[Realtime] 解析消息失败: \(error)")
    }
}
```

### 6.5 频道消息订阅管理

```swift
/// 订阅频道消息（添加到订阅列表）
func subscribeToChannelMessages(channelId: UUID) {
    subscribedChannelIds.insert(channelId)

    // 如果 Realtime 未启动，启动它
    if realtimeChannel == nil {
        Task {
            await startRealtimeSubscription()
        }
    }
}

/// 取消订阅频道消息
func unsubscribeFromChannelMessages(channelId: UUID) {
    subscribedChannelIds.remove(channelId)
    channelMessages.removeValue(forKey: channelId)

    // 如果没有订阅任何频道，停止 Realtime
    if subscribedChannelIds.isEmpty {
        Task {
            await stopRealtimeSubscription()
        }
    }
}

/// 获取频道消息列表
func getMessages(for channelId: UUID) -> [ChannelMessage] {
    channelMessages[channelId] ?? []
}
```

---

## 七、UI 组件设计

### 7.1 ChannelChatView 结构

```
┌────────────────────────────────────────────────────┐
│  ChannelChatView                                   │
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │  导航栏                                     │   │
│  │  ← 频道名称              成员数 👥 15       │   │
│  │    频道码                                   │   │
│  └────────────────────────────────────────────┘   │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │  消息列表 (ScrollViewReader)                │   │
│  │  ├─ MessageBubbleView (他人消息)            │   │
│  │  ├─ MessageBubbleView (自己消息)            │   │
│  │  └─ ...                                     │   │
│  └────────────────────────────────────────────┘   │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │  输入栏 (canSend = true)                    │   │
│  │  [输入框..................] [发送按钮]       │   │
│  └────────────────────────────────────────────┘   │
│                                                    │
│  或者                                              │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │  收音机提示 (canSend = false)               │   │
│  │  📻 收音机模式：只能收听，无法发送消息        │   │
│  └────────────────────────────────────────────┘   │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 7.2 MessageBubbleView 样式

```
自己的消息（靠右，橙色）：
                        ┌────────────────┐
                        │ 消息内容       │
                        │          10:30 │
                        └────────────────┘

他人的消息（靠左，灰色）：
┌────────────────────┐
│ 北京Alpha 📱       │
│ 消息内容           │
│ 10:31             │
└────────────────────┘
```

---

## 八、验收标准

### 8.1 数据库

- [ ] channel_messages 表已创建
- [ ] send_channel_message RPC 函数已创建
- [ ] RLS 策略完整（SELECT + INSERT）
- [ ] **Realtime Publication 已配置**（最重要！）

### 8.2 Models

- [ ] ChannelMessage 结构体（含自定义解码）
- [ ] LocationPoint 结构体（含 fromPostGIS 方法）
- [ ] MessageMetadata 结构体

### 8.3 Manager

- [ ] channelMessages 属性
- [ ] isSendingMessage 属性
- [ ] subscribedChannelIds 属性
- [ ] loadChannelMessages() 方法
- [ ] sendChannelMessage() 方法
- [ ] startRealtimeSubscription() 方法
- [ ] stopRealtimeSubscription() 方法
- [ ] handleNewMessage() 方法
- [ ] subscribeToChannelMessages() 方法
- [ ] unsubscribeFromChannelMessages() 方法
- [ ] getMessages() 方法

### 8.4 UI 功能

- [ ] ChannelChatView 有导航栏、消息列表、输入栏
- [ ] MessageBubbleView 消息气泡组件
- [ ] 自己的消息靠右橙色背景
- [ ] 他人的消息靠左灰色背景，显示呼号
- [ ] 显示设备类型图标
- [ ] 显示发送时间
- [ ] 收音机模式显示提示，隐藏输入框
- [ ] 自动滚动到最新消息

### 8.5 功能测试

- [ ] 进入频道能加载历史消息
- [ ] 可以发送消息
- [ ] **两个账号可以实时看到对方的消息（无需刷新）**
- [ ] 切换到收音机后无法发送
- [ ] 发送消息时显示 loading
- [ ] 发送成功后清空输入框

---

## 九、踩坑总结清单

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Realtime 收不到消息 | Publication 未配置 | `ALTER PUBLICATION supabase_realtime ADD TABLE channel_messages` |
| PostGIS 解析失败 | 返回的是 WKT 字符串 | 使用 LocationPoint.fromPostGIS() |
| 日期解析失败 | 格式不兼容 | 多格式兼容解析 |
| RealtimeChannelV2 找不到 | SDK 版本旧 | 更新 Supabase SDK |
| InsertAction 解码失败 | 使用了错误方法 | 用 decodeRecord() |
| AuthManager.shared 不存在 | 不是单例模式 | 用 @EnvironmentObject |
| ApocalypseTheme.text 不存在 | 属性名错误 | 用 textPrimary/textSecondary |
| 扩展 Manager 时方法在类外部 | 编辑时意外保留了 `}` | 确保新方法在类的 `}` 之前 |
| **column "callsign" does not exist** | profiles 表用的是 `username` 字段 | RPC 函数中改用 `SELECT username` |
| **walkie.talkie.radio 图标不存在** | iOS 系统没有此 SF Symbol | 改用 `antenna.radiowaves.left.and.right` 或其他替代图标 |

---

### 9.1 【实际遇到】callsign 字段不存在

#### 问题现象

```
PostgrestError: column "callsign" does not exist
```

#### 根本原因

RPC 函数 `send_channel_message` 中尝试从 `profiles` 表查询 `callsign` 字段，但实际项目中 `profiles` 表使用的是 `username` 字段。

#### 解决方案

修改 RPC 函数，将 `callsign` 改为 `username`：

```sql
-- ❌ 错误
SELECT COALESCE(callsign, '匿名幸存者')
INTO v_callsign
FROM public.profiles
WHERE id = v_user_id;

-- ✅ 正确
SELECT COALESCE(username, '匿名幸存者')
INTO v_callsign
FROM public.profiles
WHERE id = v_user_id;
```

#### 修复 SQL

```sql
CREATE OR REPLACE FUNCTION send_channel_message(...)
-- 在函数体中将 callsign 改为 username
```

---

### 9.2 【实际遇到】walkie.talkie.radio SF Symbol 不存在

#### 问题现象

```
No symbol named 'walkie.talkie.radio' found in system symbol set
```

#### 根本原因

`walkie.talkie.radio` 不是有效的 SF Symbol 名称。

#### 解决方案

使用有效的替代图标：

| 设备类型 | 原图标（错误） | 替代图标（正确） |
|----------|----------------|------------------|
| walkieTalkie | walkie.talkie.radio | `phone.badge.waveform` 或 `antenna.radiowaves.left.and.right` |

```swift
// DeviceType.swift 中修改
var iconName: String {
    switch self {
    case .radio: return "radio"
    case .walkieTalkie: return "phone.badge.waveform"  // 或 "antenna.radiowaves.left.and.right"
    case .campRadio: return "antenna.radiowaves.left.and.right"
    case .satellite: return "antenna.radiowaves.left.and.right.circle"
    }
}
```

---

## 十、设备图标对照表

| 设备类型 | SF Symbol |
|----------|-----------|
| radio | radio |
| walkieTalkie / walkie_talkie | walkie.talkie.radio |
| campRadio / camp_radio | antenna.radiowaves.left.and.right |
| satellite | antenna.radiowaves.left.and.right.circle |
| 默认 | iphone |

```swift
private func deviceIconName(for deviceType: String) -> String {
    switch deviceType {
    case "radio": return "radio"
    case "walkieTalkie", "walkie_talkie": return "walkie.talkie.radio"
    case "campRadio", "camp_radio": return "antenna.radiowaves.left.and.right"
    case "satellite": return "antenna.radiowaves.left.and.right.circle"
    default: return "iphone"
    }
}
```

---

## 十一、后续扩展

### Day 35 预告：距离过滤

| 功能 | 说明 |
|------|------|
| shouldReceiveMessage() | 判断是否应该接收消息 |
| canReceiveMessage() | 设备兼容性判断 |
| calculateDistance() | 距离计算 |
| 设备矩阵算法 | 不同设备的覆盖范围 |

---

*Day 34 消息系统开发方案 v1.0*
*包含踩坑记录和修复方案*
