//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器
//  调用 Supabase Edge Function 生成独特物品
//

import Foundation
import Supabase

/// AI 物品生成器
/// 负责调用 Edge Function 生成 AI 物品，并提供降级方案
@MainActor
final class AIItemGenerator {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    // MARK: - 配置常量

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 10.0

    // MARK: - 初始化

    private init() {
        print("🤖 [AI物品生成器] 初始化完成")
    }

    // MARK: - 公共方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 要搜刮的 POI
    ///   - count: 生成物品数量（默认 3）
    /// - Returns: AI 生成的物品数组，失败时返回 nil
    func generateItems(for poi: NearbyPOI, count: Int = 3) async -> [AIGeneratedItem]? {
        print("🤖 [AI物品生成器] 开始生成物品 - POI: \(poi.name), 类型: \(poi.type.rawValue), 危险等级: \(poi.dangerLevel)")

        // 构建请求数据
        // 注意：这里 type 传英文或 RawValue 给 AI 比较好，AI 自己会处理
        let request = GenerateItemRequest(
            poi: POIInfo(
                name: poi.name,
                type: poi.type.rawValue, // 传原始值给 AI，让 AI 知道具体类型
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            // 调用 Edge Function，带超时控制
            let response: GenerateItemResponse = try await withTimeout(seconds: requestTimeout) {
                try await supabase.functions
                    .invoke(
                        "generate-ai-item",
                        options: .init(body: request)
                    )
            }

            if response.success, let items = response.items {
                print("🤖 [AI物品生成器] ✅ 成功生成 \(items.count) 个物品")
                for item in items {
                    print("🤖 [AI物品生成器]   - \(item.name) [\(item.rarity)]")
                }
                return items
            } else {
                print("🤖 [AI物品生成器] ❌ 生成失败: \(response.error ?? "未知错误")")
                return nil
            }

        } catch {
            print("🤖 [AI物品生成器] ❌ 请求失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 带超时的异步操作包装器
    /// - Parameters:
    ///   - seconds: 超时时间（秒）
    ///   - operation: 要执行的异步操作
    /// - Returns: 操作结果
    /// - Throws: 超时或操作本身的错误
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际操作任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // 返回第一个完成的任务结果
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // 取消其他任务
            group.cancelAll()
            
            return result
        }
    }
    
    /// 超时错误
    private struct TimeoutError: LocalizedError {
        var errorDescription: String? {
            return NSLocalizedString("请求超时", comment: "网络请求超时错误")
        }
    }

    /// 生成降级物品（当 AI 不可用时）
    /// - Parameters:
    ///   - poi: 要搜刮的 POI
    ///   - count: 生成物品数量
    /// - Returns: 降级生成的物品数组
    func generateFallbackItems(for poi: NearbyPOI, count: Int = 3) -> [AIGeneratedItem] {
        print("🤖 [AI物品生成器] 使用降级方案生成物品")

        var items: [AIGeneratedItem] = []
        let rarityWeights = getRarityWeights(for: poi.dangerLevel)

        for _ in 0..<count {
            let rarity = selectRarity(weights: rarityWeights)
            let item = generateFallbackItem(for: poi, rarity: rarity)
            items.append(item)
        }

        print("🤖 [AI物品生成器] 降级生成了 \(items.count) 个物品")
        return items
    }

    // MARK: - 私有方法

    /// 根据危险等级获取稀有度权重
    private func getRarityWeights(for dangerLevel: Int) -> [String: Int] {
        switch dangerLevel {
        case 1:
            return ["common": 70, "uncommon": 25, "rare": 5, "epic": 0, "legendary": 0]
        case 2:
            return ["common": 70, "uncommon": 25, "rare": 5, "epic": 0, "legendary": 0]
        case 3:
            return ["common": 50, "uncommon": 30, "rare": 15, "epic": 5, "legendary": 0]
        case 4:
            return ["common": 0, "uncommon": 40, "rare": 35, "epic": 20, "legendary": 5]
        case 5:
            return ["common": 0, "uncommon": 0, "rare": 30, "epic": 40, "legendary": 30]
        default:
            return ["common": 60, "uncommon": 30, "rare": 10, "epic": 0, "legendary": 0]
        }
    }

    /// 根据权重选择稀有度
    private func selectRarity(weights: [String: Int]) -> String {
        let total = weights.values.reduce(0, +)
        var random = Int.random(in: 0..<total)

        for (rarity, weight) in weights {
            random -= weight
            if random < 0 {
                return rarity
            }
        }

        return "common"
    }

    /// 生成单个降级物品
    private func generateFallbackItem(for poi: NearbyPOI, rarity: String) -> AIGeneratedItem {
        let category = getFallbackCategory(for: poi.type)
        let (name, story) = getFallbackNameAndStory(category: category, rarity: rarity)

        return AIGeneratedItem(
            name: name,
            category: category, // 这里现在是英文 Key，能匹配上图标了
            rarity: rarity,
            story: story
        )
    }

    /// 根据 POI 类型获取物品分类 (返回英文 Key)
    private func getFallbackCategory(for poiType: POIType) -> String {
        switch poiType {
        case .hospital, .pharmacy:
            return "medical"
        case .supermarket, .convenience, .restaurant, .cafe:
            return "food"
        case .gasStation:
            return ["tool", "material"].randomElement()!
        case .store:
            return ["tool", "material", "other"].randomElement()!
        }
    }

    /// 获取降级物品名称和故事 (匹配英文 Key)
    private func getFallbackNameAndStory(category: String, rarity: String) -> (String, String) {
        switch category {
        case "medical":
            return getMedicalFallback(rarity: rarity)
        case "food":
            return getFoodFallback(rarity: rarity)
        case "tool":
            return getToolFallback(rarity: rarity)
        case "material":
            return getMaterialFallback(rarity: rarity)
        default:
            return getOtherFallback(rarity: rarity)
        }
    }

    // MARK: - Fallback Item Pools (内容支持国际化)

    private func getMedicalFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("急救绷带", comment: "Fallback item"), NSLocalizedString("一卷还算干净的绷带，上面沾着些许血迹。", comment: "Fallback story")),
            (NSLocalizedString("止痛药片", comment: "Fallback item"), NSLocalizedString("瓶子上的标签已经模糊，但里面的药片看起来还能用。", comment: "Fallback story")),
            (NSLocalizedString("消毒酒精", comment: "Fallback item"), NSLocalizedString("半瓶医用酒精，在这个世界里价值连城。", comment: "Fallback story")),
            (NSLocalizedString("医用纱布", comment: "Fallback item"), NSLocalizedString("无菌包装的纱布，是幸存者的必需品。", comment: "Fallback story")),
            (NSLocalizedString("退烧药", comment: "Fallback item"), NSLocalizedString("发烧在末日里可能意味着死亡，这些药很珍贵。", comment: "Fallback story"))
        ]
        return items.randomElement()!
    }

    private func getFoodFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("罐头食品", comment: "Fallback item"), NSLocalizedString("铁皮罐头上的标签早已脱落，但闻起来应该还能吃。", comment: "Fallback story")),
            (NSLocalizedString("能量棒", comment: "Fallback item"), NSLocalizedString("虽然过期了，但在末日里没人会在意保质期。", comment: "Fallback story")),
            (NSLocalizedString("矿泉水", comment: "Fallback item"), NSLocalizedString("干净的饮用水，这可能是你今天最幸运的发现。", comment: "Fallback story")),
            (NSLocalizedString("压缩饼干", comment: "Fallback item"), NSLocalizedString("军用压缩饼干，能提供足够的热量撑过一天。", comment: "Fallback story")),
            (NSLocalizedString("速溶咖啡", comment: "Fallback item"), NSLocalizedString("一小包速溶咖啡，能让你在漫长的夜里保持清醒。", comment: "Fallback story"))
        ]
        return items.randomElement()!
    }

    private func getToolFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("手电筒", comment: "Fallback item"), NSLocalizedString("电池还有电，在黑暗中这就是希望。", comment: "Fallback story")),
            (NSLocalizedString("打火机", comment: "Fallback item"), NSLocalizedString("一个还能用的打火机，生火从未如此重要。", comment: "Fallback story")),
            (NSLocalizedString("瑞士军刀", comment: "Fallback item"), NSLocalizedString("多功能工具，在末日生存中不可或缺。", comment: "Fallback story")),
            (NSLocalizedString("绳索", comment: "Fallback item"), NSLocalizedString("一卷结实的尼龙绳，用途无穷。", comment: "Fallback story")),
            (NSLocalizedString("望远镜", comment: "Fallback item"), NSLocalizedString("能让你提前发现危险，或者找到下一个避难所。", comment: "Fallback story"))
        ]
        return items.randomElement()!
    }

    private func getMaterialFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("废金属", comment: "Fallback item"), NSLocalizedString("可以用来加固防御或制作简易武器。", comment: "Fallback story")),
            (NSLocalizedString("电池", comment: "Fallback item"), NSLocalizedString("还有电的电池，在这个世界里是硬通货。", comment: "Fallback story")),
            (NSLocalizedString("布料", comment: "Fallback item"), NSLocalizedString("可以用来缝补衣服或制作绷带。", comment: "Fallback story")),
            (NSLocalizedString("螺丝钉", comment: "Fallback item"), NSLocalizedString("一把各种规格的螺丝钉，修理东西时很有用。", comment: "Fallback story")),
            (NSLocalizedString("胶带", comment: "Fallback item"), NSLocalizedString("万能胶带，在末日里能解决一半的问题。", comment: "Fallback story"))
        ]
        return items.randomElement()!
    }

    private func getOtherFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("旧杂志", comment: "Fallback item"), NSLocalizedString("记录着末日前的世界，现在只能用来生火。", comment: "Fallback story")),
            (NSLocalizedString("钥匙串", comment: "Fallback item"), NSLocalizedString("不知道能开什么锁，但也许有一天会用到。", comment: "Fallback story")),
            (NSLocalizedString("塑料袋", comment: "Fallback item"), NSLocalizedString("防水又轻便，收集物资时很有用。", comment: "Fallback story")),
            (NSLocalizedString("蜡烛", comment: "Fallback item"), NSLocalizedString("在没有电的夜晚，这是唯一的光源。", comment: "Fallback story")),
            (NSLocalizedString("笔记本", comment: "Fallback item"), NSLocalizedString("空白的笔记本，也许可以记录这段艰难的旅程。", comment: "Fallback story"))
        ]
        return items.randomElement()!
    }
}
