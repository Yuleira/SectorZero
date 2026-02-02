# Day 33：频道系统 - 完整开发方案

> 第33天开发内容：频道创建、订阅管理、频道中心UI
> **最后更新：包含踩坑记录和修复方案**

---

## 一、功能概览

### 1.1 核心功能清单

| 模块 | 功能 | 状态 |
|------|------|------|
| **数据库** | communication_channels 表 + RLS | 待完成 |
| **数据库** | channel_subscriptions 表 + RLS | 待完成 |
| **数据库** | RPC函数（创建+订阅+取消） | 待完成 |
| **Models** | ChannelType、CommunicationChannel、ChannelSubscription | 待完成 |
| **Manager** | 频道CRUD + 订阅管理方法 | 待完成 |
| **频道中心** | 我的频道 + 发现频道 Tab切换 | 待完成 |
| **创建频道** | 表单验证 + 类型选择 | 待完成 |
| **频道详情** | 订阅/取消 + 删除（创建者） | 待完成 |

### 1.2 与 Day 32 的关系

| Day 32 完成的 | Day 33 要做的 |
|--------------|--------------|
| 设备模块（收音机/对讲机等） | 频道模块（创建/订阅） |
| CommunicationManager 基础结构 | 扩展频道相关方法 |
| CommunicationModels（DeviceType等） | 扩展频道相关模型 |
| DeviceManagementView | ChannelCenterView + CreateChannelSheet + ChannelDetailView |

---

## 二、文件清单

### 2.1 需要创建的文件

| 文件 | 路径 | 说明 |
|------|------|------|
| - | `Models/CommunicationModels.swift` | 扩展（添加频道相关模型） |
| - | `Managers/CommunicationManager.swift` | 扩展（添加频道CRUD方法） |
| `ChannelCenterView.swift` | `Views/Communication/` | 频道中心（我的+发现） |
| `CreateChannelSheet.swift` | `Views/Communication/` | 创建频道表单 |
| `ChannelDetailView.swift` | `Views/Communication/` | 频道详情页（重写） |

### 2.2 数据库迁移

| 迁移名称 | 说明 |
|----------|------|
| `create_communication_channels_table` | 频道表 + RLS + 索引 |
| `create_channel_subscriptions_table` | 订阅表 + RLS + 索引 |
| `create_channel_functions` | RPC函数（生成频道码、创建频道、订阅、取消订阅） |

---

## 三、数据库设计

### 3.1 表结构

#### communication_channels 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| creator_id | UUID | 创建者ID，外键关联 auth.users |
| channel_type | TEXT | 频道类型（official/public/walkie/camp/satellite） |
| channel_code | TEXT | 频道码（唯一） |
| name | TEXT | 频道名称 |
| description | TEXT | 频道描述（可选） |
| is_active | BOOLEAN | 是否活跃（默认true） |
| member_count | INT | 成员数（默认1） |
| location | GEOGRAPHY | 位置（可选，用于范围限制） |
| created_at | TIMESTAMPTZ | 创建时间 |
| updated_at | TIMESTAMPTZ | 更新时间 |

#### channel_subscriptions 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户ID |
| channel_id | UUID | 频道ID |
| is_muted | BOOLEAN | 是否静音（默认false） |
| joined_at | TIMESTAMPTZ | 加入时间 |
| UNIQUE | (user_id, channel_id) | 唯一约束 |

### 3.2 RLS 策略

#### 频道表策略

| 操作 | 策略 | 条件 |
|------|------|------|
| SELECT | 任何人可查看活跃频道 | `is_active = true` |
| INSERT | 用户可创建频道 | `auth.uid() = creator_id` |
| UPDATE | 创建者可更新 | `auth.uid() = creator_id` |
| DELETE | 创建者可删除 | `auth.uid() = creator_id` |

#### 订阅表策略

| 操作 | 策略 | 条件 |
|------|------|------|
| SELECT | 查看自己的订阅 | `auth.uid() = user_id` |
| INSERT | 可以订阅 | `auth.uid() = user_id` |
| UPDATE | 管理自己的订阅 | `auth.uid() = user_id` |
| DELETE | 可以取消订阅 | `auth.uid() = user_id` |

### 3.3 频道码格式

| 频道类型 | 格式 | 示例 |
|----------|------|------|
| official | OFF-XXXX | OFF-MAIN |
| public | PUB-XXXXXX | PUB-A3F2K9 |
| walkie | 438.XXX MHz | 438.125 MHz |
| camp | CAMP-XXXXXX | CAMP-B7D4E2 |
| satellite | SAT-XXXXXX | SAT-C9H3J6 |

---

## 四、重要踩坑记录

### 4.1 AuthManager.shared 不存在

#### 问题现象

```
Type 'AuthManager' has no member 'shared'
```

#### 根本原因

AuthManager 在此项目中不是单例模式，而是通过 `@EnvironmentObject` 传递。

#### 错误代码

```swift
// ❌ 错误
@ObservedObject private var authManager = AuthManager.shared
```

#### 正确代码

```swift
// ✅ 正确
@EnvironmentObject var authManager: AuthManager

// 并且需要添加 import
import Supabase
```

#### 涉及文件

1. `ChannelCenterView.swift`
2. `CreateChannelSheet.swift`
3. `ChannelDetailView.swift`

---

### 4.2 ApocalypseTheme 属性名错误

#### 问题现象

```
Type 'ApocalypseTheme' has no member 'text'
Type 'ApocalypseTheme' has no member 'secondaryText'
```

#### 根本原因

ApocalypseTheme 中的属性名是 `textPrimary` 和 `textSecondary`，不是 `text` 和 `secondaryText`。

#### 错误代码

```swift
// ❌ 错误
.foregroundColor(ApocalypseTheme.text)
.foregroundColor(ApocalypseTheme.secondaryText)
```

#### 正确代码

```swift
// ✅ 正确
.foregroundColor(ApocalypseTheme.textPrimary)
.foregroundColor(ApocalypseTheme.textSecondary)
```

#### 涉及文件

所有新建的 UI 文件

---

### 4.3 删除频道失败

#### 问题现象

点击删除按钮后无反应，或者报权限错误。

#### 根本原因

数据库缺少 DELETE RLS 策略。

#### 解决方案

```sql
CREATE POLICY "创建者可以删除自己的频道"
ON public.communication_channels
FOR DELETE TO authenticated
USING (auth.uid() = creator_id);
```

---

### 4.4 CommunicationChannel 需要遵循 Identifiable

#### 问题现象

```
Cannot convert value of type 'CommunicationChannel' to expected argument type 'Binding<Item?>'
```

#### 根本原因

使用 `sheet(item:)` 时，需要模型遵循 `Identifiable` 协议。

#### 解决方案

```swift
struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    // ...
}
```

---

### 4.5 Supabase RPC 参数类型

#### 问题现象

创建频道时报参数类型错误。

#### 根本原因

Supabase Swift SDK 的 RPC 参数需要使用 `AnyJSON` 类型。

#### 正确代码

```swift
let params: [String: AnyJSON] = [
    "p_creator_id": .string(userId.uuidString),
    "p_channel_type": .string(type.rawValue),
    "p_name": .string(name),
    "p_description": description.map { .string($0) } ?? .null,
    "p_latitude": latitude.map { .double($0) } ?? .null,
    "p_longitude": longitude.map { .double($0) } ?? .null
]

let response: UUID = try await supabase
    .rpc("create_channel_with_subscription", params: params)
    .execute()
    .value
```

---

## 五、视图层级架构

### 5.1 频道中心架构

```
CommunicationTabView
    │
    ├─ 点击"频道"导航按钮
    │
    ▼
ChannelCenterView
    │
    ├─ 顶部操作栏
    │   └─ [+ 创建] 按钮 → showCreateSheet = true
    │
    ├─ Tab 切换栏
    │   ├─ [我的频道] selectedTab = 0
    │   └─ [发现频道] selectedTab = 1
    │
    ├─ 搜索栏（仅发现页面显示）
    │
    └─ 内容区域
        ├─ selectedTab == 0 → myChannelsView
        │   └─ ForEach(subscribedChannels) → ChannelRowView
        │
        └─ selectedTab == 1 → discoverChannelsView
            └─ ForEach(channels) → ChannelRowView

    │ 点击 ChannelRowView
    ▼
┌──────────────────────────────────────────────────────┐
│  ChannelDetailView (Sheet - 由 item: 管理)           │
│  ├─ 频道头像 + 名称 + 频道码                          │
│  ├─ 订阅状态标签                                     │
│  ├─ 频道介绍                                         │
│  ├─ 频道信息卡片（类型/范围/创建时间）                │
│  │                                                   │
│  ├─ 非创建者：                                       │
│  │   └─ [订阅频道] / [取消订阅] 按钮                 │
│  │                                                   │
│  └─ 创建者：                                         │
│      └─ [删除频道] 按钮（红色，需二次确认）           │
└──────────────────────────────────────────────────────┘

    │ 点击 [+ 创建] 按钮
    ▼
┌──────────────────────────────────────────────────────┐
│  CreateChannelSheet (Sheet)                          │
│  ├─ 频道类型选择（4种：公开/对讲/营地/卫星）          │
│  ├─ 频道名称输入框（2-50字符验证）                   │
│  ├─ 频道描述输入框（可选）                           │
│  └─ [创建频道] 按钮                                  │
└──────────────────────────────────────────────────────┘
```

### 5.2 Sheet 管理代码

```swift
// ChannelCenterView.swift

// 状态变量
@State private var showCreateSheet = false
@State private var selectedChannel: CommunicationChannel?

// Sheet 绑定
.sheet(isPresented: $showCreateSheet) {
    CreateChannelSheet()
}
.sheet(item: $selectedChannel) { channel in
    ChannelDetailView(channel: channel)
}
```

---

## 六、关键功能实现

### 6.1 频道中心 Tab 切换

```swift
// Tab 按钮
private func tabButton(title: String, index: Int) -> some View {
    Button(action: { selectedTab = index }) {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

            Rectangle()
                .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                .frame(height: 2)
        }
    }
    .frame(maxWidth: .infinity)
}

// Tab 切换栏
HStack(spacing: 0) {
    tabButton(title: "我的频道", index: 0)
    tabButton(title: "发现频道", index: 1)
}
```

### 6.2 表单验证

```swift
private var nameValidation: (isValid: Bool, message: String) {
    let trimmed = channelName.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty {
        return (false, "请输入频道名称")
    } else if trimmed.count < 2 {
        return (false, "名称至少2个字符")
    } else if trimmed.count > 50 {
        return (false, "名称最多50个字符")
    }
    return (true, "")
}

private var canCreate: Bool {
    nameValidation.isValid
}

// 使用
Button(action: createChannel) { ... }
    .disabled(!canCreate || isCreating)
```

### 6.3 订阅状态检查

```swift
// Manager 中
func isSubscribed(channelId: UUID) -> Bool {
    mySubscriptions.contains { $0.channelId == channelId }
}

// View 中使用
let isSubscribed = communicationManager.isSubscribed(channelId: channel.id)

// 显示已订阅标记
if isSubscribed {
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 12))
        .foregroundColor(.green)
}
```

### 6.4 删除确认弹窗

```swift
@State private var showDeleteConfirm = false

// 删除按钮
Button(action: { showDeleteConfirm = true }) {
    Label("删除频道", systemImage: "trash.fill")
}

// 确认弹窗
.alert("确认删除", isPresented: $showDeleteConfirm) {
    Button("取消", role: .cancel) {}
    Button("删除", role: .destructive) {
        deleteChannel()
    }
} message: {
    Text("删除后无法恢复，频道内所有消息也将被删除。确定要删除「\(channel.name)」吗？")
}
```

---

## 七、数据流设计

### 7.1 "我的频道" 数据加载

```
loadSubscribedChannels(userId)
    │
    ├─ 1. 查询订阅表
    │   SELECT * FROM channel_subscriptions
    │   WHERE user_id = userId
    │   → mySubscriptions: [ChannelSubscription]
    │
    ├─ 2. 提取频道ID列表
    │   channelIds = subscriptions.map { $0.channelId }
    │
    ├─ 3. 查询频道详情
    │   SELECT * FROM communication_channels
    │   WHERE id IN (channelIds)
    │   → channelList: [CommunicationChannel]
    │
    └─ 4. 组合成 SubscribedChannel
        subscribedChannels = subscriptions.compactMap { sub in
            guard let channel = channelList.first(where: { $0.id == sub.channelId })
            return SubscribedChannel(channel: channel, subscription: sub)
        }
```

### 7.2 "发现频道" 数据加载

```
loadPublicChannels()
    │
    └─ 查询所有活跃频道
       SELECT * FROM communication_channels
       WHERE is_active = true
       ORDER BY created_at DESC
       → channels: [CommunicationChannel]
```

### 7.3 创建频道流程

```
createChannel(userId, type, name, description)
    │
    ├─ 1. 调用 RPC 函数
    │   create_channel_with_subscription()
    │       ├─ 生成频道码
    │       ├─ 插入频道记录
    │       └─ 创建者自动订阅
    │
    ├─ 2. 刷新数据
    │   loadSubscribedChannels()
    │   loadPublicChannels()
    │
    └─ 3. 关闭创建表单
        dismiss()
```

---

## 八、验收标准

### 8.1 数据库

- [ ] communication_channels 表已创建
- [ ] channel_subscriptions 表已创建
- [ ] RLS 策略完整（包含 DELETE！）
- [ ] RPC 函数可用

### 8.2 Models

- [ ] ChannelType 枚举（5种类型）
- [ ] CommunicationChannel 结构体（遵循 Identifiable）
- [ ] ChannelSubscription 结构体
- [ ] SubscribedChannel 组合结构体

### 8.3 Manager

- [ ] channels 属性
- [ ] subscribedChannels 属性
- [ ] mySubscriptions 属性
- [ ] loadPublicChannels() 方法
- [ ] loadSubscribedChannels() 方法
- [ ] createChannel() 方法
- [ ] subscribeToChannel() 方法
- [ ] unsubscribeFromChannel() 方法
- [ ] isSubscribed() 方法
- [ ] deleteChannel() 方法

### 8.4 UI 功能

- [ ] 频道中心有两个Tab可切换
- [ ] 搜索框可过滤频道
- [ ] 可创建频道（表单验证正常）
- [ ] 账号A创建的频道在账号B可见
- [ ] 可订阅/取消订阅
- [ ] 已订阅显示绿色勾勾
- [ ] 创建者可看到删除按钮
- [ ] 删除需二次确认

---

## 九、踩坑总结清单

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| AuthManager.shared 不存在 | 不是单例模式 | 用 @EnvironmentObject |
| ApocalypseTheme.text 不存在 | 属性名错误 | 用 textPrimary/textSecondary |
| ApocalypseTheme.accent 不存在 | 属性名错误 | 用 `primary`（主题橙色） |
| 需要 import Supabase | 使用 AuthManager 时需要 | 添加 import Supabase |
| 删除频道失败 | 缺少 DELETE RLS 策略 | 添加删除策略 |
| sheet(item:) 报错 | 模型未遵循 Identifiable | 添加 Identifiable 协议 |
| RPC 参数类型错误 | 需要 AnyJSON 类型 | 使用 [String: AnyJSON] |
| Preview 中 AuthManager.shared 错误 | AuthManager 不是单例 | Preview 中用 `AuthManager()` |
| 扩展 Manager 时方法在类外部 | 编辑时意外保留了 `}` | 确保新方法在类的 `}` 之前 |

---

### 4.6 ApocalypseTheme.accent 不存在

#### 问题现象

```
Type 'ApocalypseTheme' has no member 'accent'
```

#### 根本原因

ApocalypseTheme 中没有 `accent` 属性，强调色属性名是 `primary`。

#### 错误代码

```swift
// ❌ 错误
.foregroundColor(ApocalypseTheme.accent)
```

#### 正确代码

```swift
// ✅ 正确
.foregroundColor(ApocalypseTheme.primary)
```

#### ApocalypseTheme 可用属性

| 属性 | 说明 |
|------|------|
| `background` | 主背景（近黑） |
| `cardBackground` | 卡片背景（深灰） |
| `primary` | 主题橙色 |
| `primaryDark` | 深橙色 |
| `textPrimary` | 主文字（白色） |
| `textSecondary` | 次要文字（灰色） |
| `textMuted` | 弱化文字 |
| `success` | 成功/绿色 |
| `warning` | 警告/黄色 |
| `danger` | 危险/红色 |
| `info` | 信息/蓝色 |

---

### 4.7 Preview 中 AuthManager.shared 错误

#### 问题现象

```
Type 'AuthManager' has no member 'shared'
```

#### 根本原因

AuthManager 不是单例模式，Preview 中需要创建新实例。

#### 错误代码

```swift
// ❌ 错误
#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
}
```

#### 正确代码

```swift
// ✅ 正确
#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager())
}
```

---

### 4.8 扩展 Manager 时方法意外放在类外部

#### 问题现象

```
Cannot find 'channels' in scope
Cannot find 'isLoading' in scope
Cannot find 'client' in scope
```

#### 根本原因

在扩展 CommunicationManager.swift 时，编辑操作意外保留了类的结束括号 `}`，导致新添加的频道方法被放在类外部。

#### 错误结构

```swift
class CommunicationManager: ObservableObject {
    // ... 设备相关方法

    func isDeviceUnlocked(...) -> Bool { ... }
}  // ← 类在这里意外关闭了

// 下面的方法都在类外部！
func loadPublicChannels() async { ... }  // ❌ 找不到 channels, isLoading, client
```

#### 正确结构

```swift
class CommunicationManager: ObservableObject {
    // ... 设备相关方法

    func isDeviceUnlocked(...) -> Bool { ... }

    // MARK: - Channel Methods

    func loadPublicChannels() async { ... }  // ✅ 在类内部
    func loadSubscribedChannels(...) async { ... }
    // ... 其他频道方法
}  // ← 类在所有方法之后关闭
```

#### 预防措施

扩展现有类时，确保：
1. 删除原有的类结束括号 `}`
2. 在新方法后面添加类结束括号
3. 编辑完成后检查文件结构

---

## 十、后续扩展

### Day 34 预告：消息系统

| 功能 | 说明 |
|------|------|
| channel_messages 表 | 频道消息存储 |
| 消息发送 | 发送消息到频道 |
| 消息接收 | 加载历史消息 |
| 聊天界面 | ChannelChatView |
| Realtime | 实时消息推送 |

---

*Day 33 频道系统开发方案 v1.0*
*包含踩坑记录和修复方案*
