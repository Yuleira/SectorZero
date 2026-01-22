//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理用户背包物品的增删改查
//

import Foundation
import Supabase
import Combine

/// 背包管理器
/// 负责管理用户背包物品的增删改查
@MainActor
final class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - 发布属性

    /// 背包物品列表
    @Published private(set) var items: [CollectedItem] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 物品定义缓存
    private var definitionsCache: [String: ItemDefinition] = [:]

    // MARK: - 初始化

    private init() {
        print("📦 [背包管理器] 初始化")
    }

    // MARK: - 公共方法

    /// 加载背包物品
    func loadItems() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("📦 [背包] 未登录")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // 1. 先加载物品定义（如果未缓存）
            if definitionsCache.isEmpty {
                await loadDefinitions()
            }

            // 2. 加载用户背包物品
            let dbItems: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("acquired_at", ascending: false)
                .execute()
                .value

            // 3. 转换为 CollectedItem
            items = dbItems.compactMap { dbItem -> CollectedItem? in
                guard let definition = definitionsCache[dbItem.itemDefinitionId] else {
                    print("📦 [背包] 警告：找不到物品定义 \(dbItem.itemDefinitionId)")
                    return nil
                }

                return CollectedItem(
                    id: dbItem.id,
                    definition: definition,
                    quality: ItemQuality(rawValue: dbItem.quality) ?? .worn,
                    foundDate: dbItem.acquiredAt ?? Date(),
                    quantity: dbItem.quantity
                )
            }

            print("📦 [背包] 加载了 \(items.count) 种物品")
        } catch {
            errorMessage = String(format: "error_load_backpack", error.localizedDescription)
            print("📦 [背包] 加载失败: \(error.localizedDescription)")
        }
    }

    /// 添加物品（支持堆叠）
    func addItems(_ newItems: [CollectedItem], sourceType: String = "exploration", sourceSessionId: UUID? = nil) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("📦 [背包] 未登录，无法添加物品")
            return
        }

        for item in newItems {
            await addSingleItem(
                userId: userId,
                item: item,
                sourceType: sourceType,
                sourceSessionId: sourceSessionId
            )
        }

        // 刷新背包
        await loadItems()
    }

    /// 移除物品
    func removeItem(itemId: UUID, quantity: Int = 1) async -> Bool {
        do {
            // 先查询当前数量
            let existing: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("id", value: itemId.uuidString)
                .execute()
                .value

            guard let item = existing.first else {
                print("📦 [背包] 物品不存在")
                return false
            }

            if item.quantity <= quantity {
                // 数量不足或刚好，删除记录
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: itemId.uuidString)
                    .execute()
                print("📦 [背包] 删除物品记录")
            } else {
                // 减少数量
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": item.quantity - quantity])
                    .eq("id", value: itemId.uuidString)
                    .execute()
                print("📦 [背包] 减少物品数量: \(item.quantity) -> \(item.quantity - quantity)")
            }

            await loadItems()
            return true
        } catch {
            errorMessage = String(format: "error_remove_item", error.localizedDescription)
            print("📦 [背包] 移除物品失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 获取物品总数
    func getTotalItemCount() -> Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    /// 按分类获取物品
    func getItems(byCategory category: ItemCategory) -> [CollectedItem] {
        return items.filter { $0.definition.category == category }
    }

    /// 清除缓存（用于切换用户时）
    func clearCache() {
        items.removeAll()
        definitionsCache.removeAll()
    }

    /// 根据物品定义 ID 移除物品（用于建筑系统的资源消耗）
    /// 优先消耗低品质物品，支持跨堆叠消耗
    /// - Parameters:
    ///   - definitionId: 物品定义 ID（如 "wood"、"stone"）
    ///   - quantity: 要移除的数量
    /// - Returns: 是否成功移除
    func removeItemsByDefinition(definitionId: String, quantity: Int) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("📦 [背包] 未登录，无法移除物品")
            return false
        }

        do {
            // 查询该物品定义的所有堆叠，按品质从低到高排序
            let qualityOrder: [ItemQuality] = [.ruined, .damaged, .worn, .good, .pristine]
            var remaining = quantity

            for quality in qualityOrder {
                guard remaining > 0 else { break }

                let matchingItems: [DBInventoryItem] = try await supabase
                    .from("inventory_items")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("item_definition_id", value: definitionId)
                    .eq("quality", value: quality.rawValue)
                    .execute()
                    .value

                for item in matchingItems {
                    guard remaining > 0 else { break }

                    let toRemove = min(remaining, item.quantity)

                    if item.quantity <= toRemove {
                        // 删除整个堆叠
                        try await supabase
                            .from("inventory_items")
                            .delete()
                            .eq("id", value: item.id.uuidString)
                            .execute()
                        print("📦 [背包] 删除堆叠: \(definitionId) (\(quality.rawValue)) x\(item.quantity)")
                    } else {
                        // 减少数量
                        try await supabase
                            .from("inventory_items")
                            .update(["quantity": item.quantity - toRemove])
                            .eq("id", value: item.id.uuidString)
                            .execute()
                        print("📦 [背包] 减少数量: \(definitionId) (\(quality.rawValue)) \(item.quantity) -> \(item.quantity - toRemove)")
                    }

                    remaining -= toRemove
                }
            }

            // 检查是否完全消耗
            if remaining > 0 {
                print("📦 [背包] 资源不足: \(definitionId)，缺少 \(remaining)")
                return false
            }

            // 刷新背包
            await loadItems()
            print("📦 [背包] 成功消耗: \(definitionId) x\(quantity)")
            return true
        } catch {
            errorMessage = String(format: "error_remove_item", error.localizedDescription)
            print("📦 [背包] 移除物品失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 获取资源汇总（用于建筑系统验证资源）
    /// - Returns: [物品定义ID: 总数量]
    func getResourceSummary() -> [String: Int] {
        var summary: [String: Int] = [:]
        for item in items {
            let id = item.definition.id
            summary[id, default: 0] += item.quantity
        }
        return summary
    }

    // MARK: - 私有方法

    /// 加载物品定义到缓存
    private func loadDefinitions() async {
        do {
            let definitions: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            definitionsCache = Dictionary(uniqueKeysWithValues: definitions.map {
                ($0.id, $0.toItemDefinition())
            })

            print("📦 [背包] 缓存了 \(definitionsCache.count) 个物品定义")
        } catch {
            print("📦 [背包] 加载物品定义失败: \(error.localizedDescription)")
            // 使用备用数据
            loadFallbackDefinitions()
        }
    }

    /// 加载备用物品定义
    private func loadFallbackDefinitions() {
        let fallbackItems: [(String, String, String, ItemCategory, String, ItemRarity)] = [
            ("water_bottle", "item_water_bottle", "item_water_bottle_desc", .water, "drop.fill", .common),
            ("canned_beans", "item_canned_beans", "item_canned_beans_desc", .food, "takeoutbag.and.cup.and.straw.fill", .common),
            ("bandage", "item_bandage", "item_bandage_desc", .medical, "bandage.fill", .common),
            ("first_aid_kit", "item_first_aid_kit", "item_first_aid_kit_desc", .medical, "cross.case.fill", .rare),
            ("antibiotics", "item_antibiotics", "item_antibiotics_desc", .medical, "pills.fill", .epic),
            ("scrap_metal", "item_scrap_metal", "item_scrap_metal_desc", .material, "gearshape.fill", .common),
            ("rope", "item_rope", "item_rope_desc", .tool, "lasso", .common)
        ]

        for item in fallbackItems {
            definitionsCache[item.0] = ItemDefinition(
                id: item.0,
                name: item.1,
                description: item.2,
                category: item.3,
                icon: item.4,
                rarity: item.5
            )
        }

        print("📦 [背包] 使用备用物品定义")
    }

    /// 添加单个物品（支持堆叠）
    private func addSingleItem(
        userId: UUID,
        item: CollectedItem,
        sourceType: String,
        sourceSessionId: UUID?
    ) async {
        do {
            // 检查是否存在相同物品（同定义 + 同品质）
            let existing: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("item_definition_id", value: item.definition.id)
                .eq("quality", value: item.quality.rawValue)
                .execute()
                .value

            if let existingItem = existing.first {
                // 堆叠：更新数量
                try await supabase
                    .from("inventory_items")
                    .update(["quantity": existingItem.quantity + item.quantity])
                    .eq("id", value: existingItem.id.uuidString)
                    .execute()

                print("📦 [背包] 堆叠物品: \(item.definition.name) x\(item.quantity) (总计: \(existingItem.quantity + item.quantity))")
            } else {
                // 新增记录
                let insertData = InsertInventoryItem(
                    userId: userId.uuidString,
                    itemDefinitionId: item.definition.id,
                    quality: item.quality.rawValue,
                    quantity: item.quantity,
                    sourceType: sourceType,
                    sourceSessionId: sourceSessionId?.uuidString
                )

                try await supabase
                    .from("inventory_items")
                    .insert(insertData)
                    .execute()

                print("📦 [背包] 新增物品: \(item.definition.name) x\(item.quantity)")
            }
        } catch {
            print("📦 [背包] 添加物品失败: \(error.localizedDescription)")
        }
    }
}
