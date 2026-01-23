//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  负责根据探索等级生成随机奖励物品
//

import Foundation
import Supabase

/// 奖励生成器
/// 负责根据探索等级生成随机奖励
@MainActor
final class RewardGenerator {

    // MARK: - 单例

    static let shared = RewardGenerator()

    // MARK: - 属性

    /// 物品定义缓存
    private var itemDefinitionsCache: [ItemRarity: [DBItemDefinition]] = [:]

    /// 是否已加载
    private var isLoaded = false

    // MARK: - 初始化

    private init() {
        print("🎁 [奖励生成器] 初始化")
    }

    // MARK: - 公共方法

    /// 生成奖励物品
    /// - Parameter tier: 奖励等级
    /// - Returns: 收集到的物品数组
    func generateRewards(tier: RewardTier) async -> [CollectedItem] {
        guard tier != .none else { return [] }

        // 确保物品定义已加载
        await loadItemDefinitionsIfNeeded()

        var items: [CollectedItem] = []
        let probabilities = tier.rarityProbabilities

        for _ in 0..<tier.itemCount {
            // 1. 根据概率选择稀有度
            let rarity = selectRarity(probabilities: probabilities)

            // 2. 从该稀有度中随机选择物品
            guard let definition = selectRandomItem(rarity: rarity) else {
                continue
            }

            // 3. 随机品质
            let quality = randomQuality()

            // 4. 创建物品
            let item = CollectedItem(
                definition: definition.toItemDefinition(),
                quality: quality,
                foundDate: Date(),
                quantity: 1
            )

            items.append(item)
            print("🎁 [奖励] 生成物品: \(definition.name) [\(rarity.displayName)] [\(quality.rawValue)]")
        }

        print("🎁 [奖励] 共生成 \(items.count) 个物品")
        return items
    }

    /// 预加载物品定义
    func preloadItemDefinitions() async {
        await loadItemDefinitionsIfNeeded()
    }

    // MARK: - 私有方法

    /// 加载物品定义（如果需要）
    private func loadItemDefinitionsIfNeeded() async {
        guard !isLoaded else { return }

        do {
            let definitions: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            // 按稀有度分组
            itemDefinitionsCache = [:]
            for rarity in ItemRarity.allCases {
                itemDefinitionsCache[rarity] = definitions.filter { $0.rarity == rarity.rawValue }
            }

            isLoaded = true
            print("🎁 [奖励] 加载了 \(definitions.count) 个物品定义")
        } catch {
            print("🎁 [奖励] 加载物品定义失败: \(error.localizedDescription)")
            // 使用本地备用数据
            loadFallbackDefinitions()
        }
    }

    /// 加载备用本地数据
    private func loadFallbackDefinitions() {
        // 本地硬编码的备用物品（当数据库不可用时）
        let fallbackItems: [DBItemDefinition] = [
            // Common
            DBItemDefinition(id: "water_bottle", name: NSLocalizedString("item_pure_water", comment: ""), description: NSLocalizedString("item_pure_water_desc", comment: ""), category: "water", icon: "drop.fill", rarity: "common", baseValue: nil, isActive: true),
            DBItemDefinition(id: "canned_beans", name: NSLocalizedString("item_canned_beans", comment: ""), description: NSLocalizedString("item_canned_beans_desc", comment: ""), category: "food", icon: "takeoutbag.and.cup.and.straw.fill", rarity: "common", baseValue: nil, isActive: true),
            DBItemDefinition(id: "bandage", name: NSLocalizedString("item_bandage", comment: ""), description: NSLocalizedString("item_bandage_desc", comment: ""), category: "medical", icon: "bandage.fill", rarity: "common", baseValue: nil, isActive: true),
            DBItemDefinition(id: "scrap_metal", name: NSLocalizedString("item_scrap_metal", comment: ""), description: NSLocalizedString("item_scrap_metal_desc", comment: ""), category: "material", icon: "gearshape.fill", rarity: "common", baseValue: nil, isActive: true),
            DBItemDefinition(id: "rope", name: NSLocalizedString("item_rope", comment: ""), description: NSLocalizedString("item_rope_desc", comment: ""), category: "tool", icon: "line.diagonal", rarity: "common", baseValue: nil, isActive: true),
            // Rare
            DBItemDefinition(id: "first_aid_kit", name: NSLocalizedString("item_first_aid_kit", comment: ""), description: NSLocalizedString("item_first_aid_kit_desc", comment: ""), category: "medical", icon: "cross.case.fill", rarity: "rare", baseValue: nil, isActive: true),
            DBItemDefinition(id: "flashlight", name: NSLocalizedString("item_flashlight", comment: ""), description: NSLocalizedString("item_flashlight_desc", comment: ""), category: "tool", icon: "flashlight.on.fill", rarity: "rare", baseValue: nil, isActive: true),
            DBItemDefinition(id: "canned_meat", name: NSLocalizedString("item_canned_meat", comment: ""), description: NSLocalizedString("item_canned_meat_desc", comment: ""), category: "food", icon: "fork.knife", rarity: "rare", baseValue: nil, isActive: true),
            // Epic
            DBItemDefinition(id: "antibiotics", name: NSLocalizedString("item_antibiotics", comment: ""), description: NSLocalizedString("item_antibiotics_desc", comment: ""), category: "medical", icon: "pills.fill", rarity: "epic", baseValue: nil, isActive: true),
            DBItemDefinition(id: "radio", name: NSLocalizedString("item_radio", comment: ""), description: NSLocalizedString("item_radio_desc", comment: ""), category: "tool", icon: "antenna.radiowaves.left.and.right", rarity: "epic", baseValue: nil, isActive: true)
        ]

        itemDefinitionsCache = [:]
        for rarity in ItemRarity.allCases {
            itemDefinitionsCache[rarity] = fallbackItems.filter { $0.rarity == rarity.rawValue }
        }

        isLoaded = true
        print("🎁 [奖励] 使用备用物品数据（\(fallbackItems.count) 个）")
    }

    /// 根据概率选择稀有度
    private func selectRarity(probabilities: [Double]) -> ItemRarity {
        let random = Double.random(in: 0..<1)
        var cumulative = 0.0

        for (index, probability) in probabilities.enumerated() {
            cumulative += probability
            if random < cumulative {
                return ItemRarity.allCases[index]
            }
        }

        return .common
    }

    /// 从指定稀有度中随机选择物品
    private func selectRandomItem(rarity: ItemRarity) -> DBItemDefinition? {
        guard let items = itemDefinitionsCache[rarity], !items.isEmpty else {
            // 降级到普通物品
            print("🎁 [奖励] 稀有度 \(rarity.displayName) 无可用物品，降级到普通")
            return itemDefinitionsCache[.common]?.randomElement()
        }
        return items.randomElement()
    }

    /// 随机生成品质
    private func randomQuality() -> ItemQuality {
        let random = Double.random(in: 0..<1)

        // 品质概率分布
        // 完美: 5%, 良好: 25%, 陈旧: 40%, 破损: 25%, 报废: 5%
        switch random {
        case 0..<0.05: return .pristine
        case 0.05..<0.30: return .good
        case 0.30..<0.70: return .worn
        case 0.70..<0.95: return .damaged
        default: return .ruined
        }
    }
}
