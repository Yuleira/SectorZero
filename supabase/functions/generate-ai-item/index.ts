// supabase/functions/generate-ai-item/index.ts
//
// AI Item Generator Edge Function
// Calls Alibaba Cloud Dashscope (qwen-flash) to generate unique items for POI scavenging
//

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

// Alibaba Cloud Dashscope configuration (International endpoint)
const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

// System prompt for item generation
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据玩家搜刮的地点，生成符合场景的物品列表。每个物品包含：
- name: 独特的物品名称（15字以内），可以暗示前主人身份或物品来历
- category: 物品分类（医疗/食物/工具/武器/材料/水/其他）
- rarity: 稀有度（common/uncommon/rare/epic/legendary）
- story: 背景故事（50-100字），营造末日氛围，有画面感

生成规则：
1. 物品类型要与地点相关（医院出医疗物品，超市出食物，加油站出工具和燃料）
2. 名称要有创意，可以暗示物品的来历或前主人的故事
3. 故事要简短但有画面感，让玩家能想象出末日前的场景
4. 稀有度越高，名称越独特，故事越精彩
5. 可以有黑色幽默，但不要太血腥

风格：末日生存，略带黑色幽默，偶尔温情

只返回 JSON 数组格式，不要其他任何内容。示例：
[{"name":"物品名","category":"分类","rarity":"稀有度","story":"故事"}]`;

// Rarity weights based on danger level
function getRarityWeights(dangerLevel: number): Record<string, number> {
    switch (dangerLevel) {
        case 1:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
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

// Rarity display names for prompt
const rarityNames: Record<string, string> = {
    common: "普通",
    uncommon: "优秀",
    rare: "稀有",
    epic: "史诗",
    legendary: "传奇"
};

// CORS headers
const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const { poi, itemCount = 3 } = await req.json();

        // Validate input
        if (!poi || !poi.name || !poi.type) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing POI information" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const dangerLevel = poi.dangerLevel || 2;
        const rarityWeights = getRarityWeights(dangerLevel);

        // Build rarity distribution string
        const rarityDistribution = Object.entries(rarityWeights)
            .filter(([_, weight]) => weight > 0)
            .map(([rarity, weight]) => `- ${rarityNames[rarity]}(${rarity}): ${weight}%`)
            .join("\n");

        const userPrompt = `搜刮地点：${poi.name}（${poi.type}类型，危险等级 ${dangerLevel}/5）

请生成 ${itemCount} 个物品。

稀有度分布参考（请大致按此比例分配）：
${rarityDistribution}

返回纯 JSON 数组格式，不要 markdown 代码块。`;

        console.log(`[generate-ai-item] Generating ${itemCount} items for ${poi.name} (danger: ${dangerLevel})`);

        const completion = await openai.chat.completions.create({
            model: "qwen-flash",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            max_tokens: 1000,
            temperature: 0.8
        });

        const content = completion.choices[0]?.message?.content;

        if (!content) {
            throw new Error("Empty response from AI");
        }

        // Parse JSON response (handle possible markdown code blocks)
        let jsonContent = content.trim();
        if (jsonContent.startsWith("```")) {
            jsonContent = jsonContent.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
        }

        const items = JSON.parse(jsonContent);

        console.log(`[generate-ai-item] Successfully generated ${items.length} items`);

        return new Response(
            JSON.stringify({ success: true, items }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);

        return new Response(
            JSON.stringify({
                success: false,
                error: error instanceof Error ? error.message : "Unknown error"
            }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
