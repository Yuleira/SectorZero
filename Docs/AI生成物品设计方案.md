# AI 生成物品设计方案

## 概述

在 EarthLord 中，**所有搜刮获得的物品都由 AI 实时生成**。通过 Supabase Edge Function 接入阿里云百炼的 qwen-flash 模型，根据 POI 的类型、名称和危险值，生成具有独特名称和背景故事的物品。

---

## 核心原理

### 为什么要用 AI 生成？

传统游戏的物品是预设的，玩家搜刮到的永远是"罐头"、"绷带"这些固定名称。

使用 AI 生成后：
- 每个物品都有**独特的名称**（如"老张的最后晚餐"）
- 每个物品都有**背景故事**（暗示末日前的生活）
- 物品与**搜刮地点相关**（医院出医疗物品，超市出食物）
- 大大增加游戏的**趣味性和沉浸感**

### 技术架构

```
┌─────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│   App 客户端 │ ──> │  Supabase Edge Function  │ ──> │  阿里云百炼      │
│  (Swift)    │ <── │  (TypeScript/Deno)       │ <── │  (qwen-flash)   │
└─────────────┘     └──────────────────────────┘     └─────────────────┘
```

**为什么用 Edge Function？**
1. **安全**：API Key 存储在服务端，不暴露给客户端
2. **灵活**：可以随时切换 AI 模型，客户端无感知
3. **可控**：可以添加速率限制、日志等

**为什么用阿里云百炼？**
1. **便宜**：qwen-flash 成本极低（约 ¥0.0007/次）
2. **快速**：响应通常在 1-2 秒内
3. **中文好**：通义千问对中文理解最好
4. **有国际端点**：Supabase 在海外，需要国际版 API

---

## 生成规则

### 触发条件

**100% 触发**：每次搜刮 POI 时，所有物品都由 AI 生成。

### 物品等级由 POI 危险值决定

| POI 危险值 | 物品稀有度分布 | 说明 |
|-----------|--------------|------|
| 1-2 (低危) | 普通 70%, 优秀 25%, 稀有 5% | 便利店、公园等安全区域 |
| 3 (中危) | 普通 50%, 优秀 30%, 稀有 15%, 史诗 5% | 超市、办公楼等 |
| 4 (高危) | 优秀 40%, 稀有 35%, 史诗 20%, 传奇 5% | 医院、警察局等 |
| 5 (极危) | 稀有 30%, 史诗 40%, 传奇 30% | 军事基地、研究所等 |

**原理**：危险越高，收益越大。这激励玩家挑战高危区域。

### 物品分类由 POI 类型决定

| POI 类型 | 主要物品分类 | 示例 |
|---------|------------|------|
| hospital/pharmacy | 医疗 | 绷带、药品、急救包 |
| supermarket/convenience | 食物 | 罐头、饮料、零食 |
| hardware/gas_station | 工具 | 手电筒、绳索、燃料 |
| police/military | 武器 | 警棍、防弹衣、武器 |
| residential | 杂项 | 衣物、日用品 |

---

## Edge Function 实现

### 工作流程

```
1. 客户端发起搜刮请求
        ↓
2. 发送 POI 信息到 Edge Function
   - POI 名称、类型、危险值
        ↓
3. Edge Function 调用阿里云百炼 API
   - 使用系统提示词定义生成规则
   - 传入 POI 上下文
        ↓
4. AI 返回生成的物品列表
   - 独特名称 + 背景故事
        ↓
5. 客户端显示搜刮结果
```

### 系统提示词设计（关键）

提示词决定了 AI 生成的质量：

```
你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据玩家搜刮的地点，生成符合场景的物品。

生成规则：
1. 物品名称要有创意（15字以内），可以暗示前主人身份或物品来历
2. 背景故事要简短有画面感（50-100字），营造末日氛围
3. 物品类别要与地点相关（医院出医疗物品，超市出食物）
4. 稀有度越高，名称越独特，故事越精彩

风格：末日生存，可以有黑色幽默，但不要太血腥

只返回 JSON 格式，不要其他内容。
```

### 请求与响应格式

**请求：**
```json
{
  "poi": {
    "name": "协和医院急诊室",
    "type": "hospital",
    "dangerLevel": 4
  },
  "itemCount": 3
}
```

**响应：**
```json
{
  "success": true,
  "items": [
    {
      "name": "「最后的希望」应急包",
      "category": "医疗",
      "rarity": "epic",
      "story": "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它..."
    },
    {
      "name": "护士站的咖啡罐头",
      "category": "食物",
      "rarity": "rare",
      "story": "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。"
    }
  ]
}
```

---

## Edge Function 代码

```typescript
// supabase/functions/generate-ai-item/index.ts

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

// 阿里云百炼配置（必须用国际版端点）
const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。

根据搜刮地点生成物品列表，每个物品包含：
- name: 独特名称（15字以内）
- category: 分类（医疗/食物/工具/武器/材料）
- rarity: 稀有度（common/uncommon/rare/epic/legendary）
- story: 背景故事（50-100字）

规则：
1. 物品类型要与地点相关
2. 名称要有创意，暗示前主人或来历
3. 故事要有画面感，营造末日氛围
4. 可以有黑色幽默

只返回 JSON 数组，不要其他内容。`;

// 根据危险值生成稀有度分布
function getRarityWeights(dangerLevel: number) {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
        case 3:
            return { common: 50, uncommon: 30, rare: 15, epic: 5, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 40, rare: 35, epic: 20, legendary: 5 };
        case 5:
            return { common: 0, uncommon: 0, rare: 30, epic: 40, legendary: 30 };
        default:
            return { common: 60, uncommon: 30, rare: 10, epic: 0, legendary: 0 };
    }
}

Deno.serve(async (req: Request) => {
    try {
        const { poi, itemCount = 3 } = await req.json();
        const rarityWeights = getRarityWeights(poi.dangerLevel);

        const userPrompt = `搜刮地点：${poi.name}（${poi.type}类型，危险等级 ${poi.dangerLevel}/5）

请生成 ${itemCount} 个物品。

稀有度分布参考：
- 普通(common): ${rarityWeights.common}%
- 优秀(uncommon): ${rarityWeights.uncommon}%
- 稀有(rare): ${rarityWeights.rare}%
- 史诗(epic): ${rarityWeights.epic}%
- 传奇(legendary): ${rarityWeights.legendary}%

返回 JSON 数组格式。`;

        const completion = await openai.chat.completions.create({
            model: "qwen-flash",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            max_tokens: 800,
            temperature: 0.8
        });

        const content = completion.choices[0]?.message?.content;
        const items = JSON.parse(content || "[]");

        return new Response(
            JSON.stringify({ success: true, items }),
            { headers: { "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});
```

---

## 客户端实现

### 调用 Edge Function

```swift
// AIItemGenerator.swift

@MainActor
final class AIItemGenerator {
    static let shared = AIItemGenerator()

    private let functionURL = "https://你的项目ID.supabase.co/functions/v1/generate-ai-item"

    /// 为 POI 生成 AI 物品
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        let request = GenerateRequest(
            poi: POIInfo(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            let response: GenerateResponse = try await supabase.functions
                .invoke("generate-ai-item", options: .init(body: request))

            if response.success {
                return response.items
            }
        } catch {
            print("[AIItemGenerator] 生成失败: \(error)")
        }

        return nil
    }
}
```

### 搜刮流程

```swift
// ExplorationManager.swift

func scavengePOI(_ poi: POI) async -> [GeneratedRewardItem] {
    // 计算物品数量（基于 POI 规模）
    let itemCount = calculateItemCount(for: poi)

    // 调用 AI 生成物品
    guard let aiItems = await AIItemGenerator.shared.generateItems(
        for: poi,
        count: itemCount
    ) else {
        // AI 失败时使用备用方案
        return generateFallbackItems(for: poi)
    }

    // 转换为游戏物品
    return aiItems.map { item in
        GeneratedRewardItem(
            itemId: UUID(),
            itemName: item.name,
            quantity: 1,
            quality: "pristine",
            rarity: item.rarity,
            category: item.category,
            isAIGenerated: true,
            aiStory: item.story
        )
    }
}
```

---

## UI 展示

### 搜刮结果界面

```
┌────────────────────────────────────────┐
│  ✨ 搜刮成功！                          │
│  📍 协和医院急诊室                       │
├────────────────────────────────────────┤
│                                        │
│  🩹「最后的希望」应急包           [史诗] │
│  ──────────────────────────────        │
│  "这个急救包上贴着一张便签：            │
│   '给值夜班的自己准备的'..."           │
│                                   [展开]│
│                                        │
│  ☕ 护士站的咖啡罐头              [稀有] │
│  ──────────────────────────────        │
│  "罐头上写着'夜班续命神器'..."         │
│                                   [展开]│
│                                        │
│  💊 急诊科常备止痛片             [优秀] │
│  ──────────────────────────────        │
│  "瓶身上还贴着患者的名字..."           │
│                                   [展开]│
│                                        │
└────────────────────────────────────────┘
```

---

## 部署步骤

### 1. 获取阿里云百炼 API Key

1. 访问 [百炼控制台](https://dashscope.console.aliyun.com/)
2. 注册阿里云账号并开通百炼服务（免费）
3. 在「API-KEY 管理」中点击「创建」
4. 复制保存生成的 API Key（以 `sk-` 开头）

**免费额度**：新用户每个模型有 100 万 tokens 免费额度，足够测试和初期使用。

### 2. 使用 MCP 部署 Edge Function

在 Claude Code 中使用 Supabase MCP 工具部署：

```
请帮我把 supabase/functions/generate-ai-item 部署到 Supabase
```

Claude Code 会自动：
- 读取函数代码
- 调用 MCP 的 `deploy_edge_function` 工具
- 完成部署

### 3. 手动配置 API Key（必须）

**重要**：API Key 不能通过 MCP 设置，需要手动在 Supabase 后台配置。

**步骤：**

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择你的项目
3. 左侧菜单点击 **Edge Functions**
4. 点击 **Manage Secrets**（或项目设置 → Edge Functions → Secrets）
5. 添加新的 Secret：
   - **Name**: `DASHSCOPE_API_KEY`
   - **Value**: `sk-你的API密钥`
6. 点击 **Save**

```
┌─────────────────────────────────────────────────┐
│  Supabase Dashboard > Edge Functions > Secrets  │
├─────────────────────────────────────────────────┤
│                                                 │
│  Name                    Value                  │
│  ─────────────────────   ──────────────────     │
│  DASHSCOPE_API_KEY       sk-xxxxxxxx...   [👁]  │
│                                                 │
│                              [+ Add new secret] │
└─────────────────────────────────────────────────┘
```

### 4. 测试 Edge Function

**方法一：使用 curl**

```bash
curl -X POST https://你的项目ID.supabase.co/functions/v1/generate-ai-item \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 你的anon_key" \
  -d '{
    "poi": {
      "name": "便利店",
      "type": "convenience_store",
      "dangerLevel": 2
    },
    "itemCount": 3
  }'
```

**方法二：让 Claude Code 测试**

```
请帮我测试 generate-ai-item Edge Function，
用一个危险等级为 3 的超市作为测试数据
```

**预期返回：**

```json
{
  "success": true,
  "items": [
    {
      "name": "过期三天的能量饮料",
      "category": "食物",
      "rarity": "uncommon",
      "story": "瓶身上的促销标签还在：'买二送一'..."
    }
  ]
}
```

---

## 成本分析

### qwen-flash 定价（国际版）

| 项目 | 价格 |
|-----|------|
| 输入 | ¥0.000367/千tokens |
| 输出 | ¥0.002936/千tokens |

### 每次调用成本

- 输入约 300 tokens：¥0.00011
- 输出约 400 tokens：¥0.00117
- **总计：约 ¥0.0013/次**

### 月度成本估算

| 场景 | 日调用量 | 月成本 |
|-----|---------|--------|
| 测试阶段 | 50 次 | ¥2 |
| 正常使用 | 200 次 | ¥8 |
| 活跃使用 | 500 次 | ¥20 |

**免费额度**：新用户有 100 万 tokens，足够数千次调用。

---

## 降级方案

当 AI 服务不可用时，使用预设物品库：

```swift
func generateFallbackItems(for poi: POI) -> [GeneratedRewardItem] {
    // 从本地预设物品库中随机选择
    let presetItems = PresetItemDatabase.items(for: poi.type)
    return presetItems.shuffled().prefix(3).map { ... }
}
```

---

## 关键文件

| 文件 | 说明 |
|-----|------|
| `supabase/functions/generate-ai-item/index.ts` | Edge Function |
| `EarthLord/Managers/AIItemGenerator.swift` | 客户端 AI 调用 |
| `EarthLord/Managers/ExplorationManager.swift` | 搜刮逻辑集成 |
| `EarthLord/Views/Exploration/ScavengeResultView.swift` | 结果展示 |
