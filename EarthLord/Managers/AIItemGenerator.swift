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
            return NSLocalizedString("error_request_timeout", comment: "Network request timeout")
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
            (NSLocalizedString("item_first_aid_bandage", comment: "Item name"), NSLocalizedString("item_first_aid_bandage_story", comment: "Item story")),
            (NSLocalizedString("item_painkillers", comment: "Item name"), NSLocalizedString("item_painkillers_story", comment: "Item story")),
            (NSLocalizedString("item_rubbing_alcohol", comment: "Item name"), NSLocalizedString("item_rubbing_alcohol_story", comment: "Item story")),
            (NSLocalizedString("item_medical_gauze", comment: "Item name"), NSLocalizedString("item_medical_gauze_story", comment: "Item story")),
            (NSLocalizedString("item_fever_medicine", comment: "Item name"), NSLocalizedString("item_fever_medicine_story", comment: "Item story"))
        ]
        return items.randomElement()!
    }

    private func getFoodFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("item_canned_food", comment: "Item name"), NSLocalizedString("item_canned_food_story", comment: "Item story")),
            (NSLocalizedString("item_energy_bar", comment: "Item name"), NSLocalizedString("item_energy_bar_story", comment: "Item story")),
            (NSLocalizedString("item_bottled_water", comment: "Item name"), NSLocalizedString("item_bottled_water_story", comment: "Item story")),
            (NSLocalizedString("item_hardtack", comment: "Item name"), NSLocalizedString("item_hardtack_story", comment: "Item story")),
            (NSLocalizedString("item_instant_coffee", comment: "Item name"), NSLocalizedString("item_instant_coffee_story", comment: "Item story"))
        ]
        return items.randomElement()!
    }

    private func getToolFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("item_flashlight", comment: "Item name"), NSLocalizedString("item_flashlight_story", comment: "Item story")),
            (NSLocalizedString("item_lighter", comment: "Item name"), NSLocalizedString("item_lighter_story", comment: "Item story")),
            (NSLocalizedString("item_swiss_army_knife", comment: "Item name"), NSLocalizedString("item_swiss_army_knife_story", comment: "Item story")),
            (NSLocalizedString("item_rope", comment: "Item name"), NSLocalizedString("item_rope_story", comment: "Item story")),
            (NSLocalizedString("item_binoculars", comment: "Item name"), NSLocalizedString("item_binoculars_story", comment: "Item story"))
        ]
        return items.randomElement()!
    }

    private func getMaterialFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("item_scrap_metal", comment: "Item name"), NSLocalizedString("item_scrap_metal_story", comment: "Item story")),
            (NSLocalizedString("item_battery", comment: "Item name"), NSLocalizedString("item_battery_story", comment: "Item story")),
            (NSLocalizedString("item_fabric", comment: "Item name"), NSLocalizedString("item_fabric_story", comment: "Item story")),
            (NSLocalizedString("item_screws", comment: "Item name"), NSLocalizedString("item_screws_story", comment: "Item story")),
            (NSLocalizedString("item_duct_tape", comment: "Item name"), NSLocalizedString("item_duct_tape_story", comment: "Item story"))
        ]
        return items.randomElement()!
    }

    private func getOtherFallback(rarity: String) -> (String, String) {
        let items: [(String, String)] = [
            (NSLocalizedString("item_old_magazine", comment: "Item name"), NSLocalizedString("item_old_magazine_story", comment: "Item story")),
            (NSLocalizedString("item_keychain", comment: "Item name"), NSLocalizedString("item_keychain_story", comment: "Item story")),
            (NSLocalizedString("item_plastic_bag", comment: "Item name"), NSLocalizedString("item_plastic_bag_story", comment: "Item story")),
            (NSLocalizedString("item_candle", comment: "Item name"), NSLocalizedString("item_candle_story", comment: "Item story")),
            (NSLocalizedString("item_notebook", comment: "Item name"), NSLocalizedString("item_notebook_story", comment: "Item story"))
        ]
        return items.randomElement()!
    }
}
