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
    
    /// Demo seed guard
    private var isSeedingDemoResources = false
    
    /// Demo seed flag
    private let demoSeedKey = "demo_seeded_basic_resources"
    
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
            // 1b. 确保建筑资源定义存在（ID 与 building_templates.json 的 required_resources 一致）
            ensureBuildingResourceDefinitions()
            
            // Demo: auto-seed on first launch (DEBUG)
            await seedDemoResourcesIfNeeded(userId: userId)
            
            // 2. 加载用户背包物品
            let dbItems: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("acquired_at", ascending: false)
                .execute()
                .value
            
            // 3. 转换为 CollectedItem（lookup 用小写与 building 资源 ID 对齐）
            items = dbItems.compactMap { dbItem -> CollectedItem? in
                let key = dbItem.itemDefinitionId.lowercased()
                guard let definition = definitionsCache[key] ?? definitionsCache[dbItem.itemDefinitionId] else {
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
        let normalizedId = definitionId.lowercased()
        
        do {
            // 查询该物品定义的所有堆叠，按品质从低到高排序；item_definition_id 与 building JSON 一致（wood/stone 等）
            let qualityOrder: [ItemQuality] = [.ruined, .damaged, .worn, .good, .pristine]
            var remaining = quantity
            
            for quality in qualityOrder {
                guard remaining > 0 else { break }
                
                let matchingItems: [DBInventoryItem] = try await supabase
                    .from("inventory_items")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .eq("item_definition_id", value: normalizedId)
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
                        print("📦 [背包] 删除堆叠: \(normalizedId) (\(quality.rawValue)) x\(item.quantity)")
                    } else {
                        // 减少数量
                        try await supabase
                            .from("inventory_items")
                            .update(["quantity": item.quantity - toRemove])
                            .eq("id", value: item.id.uuidString)
                            .execute()
                        print("📦 [背包] 减少数量: \(normalizedId) (\(quality.rawValue)) \(item.quantity) -> \(item.quantity - toRemove)")
                    }
                    
                    remaining -= toRemove
                }
            }
            
            // 检查是否完全消耗
            if remaining > 0 {
                print("📦 [背包] 资源不足: \(normalizedId)，缺少 \(remaining)")
                return false
            }
            
            // 刷新背包
            await loadItems()
            print("📦 [背包] 成功消耗: \(normalizedId) x\(quantity)")
            return true
        } catch {
            errorMessage = String(format: "error_remove_item", error.localizedDescription)
            print("📦 [背包] 移除物品失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 获取资源汇总（用于建筑系统验证资源）
    /// - Returns: [物品定义ID: 总数量]，key 使用小写与 building_templates.json 的 required_resources 对齐
    func getResourceSummary() -> [String: Int] {
        var summary: [String: Int] = [:]
        for item in items {
            let key = item.definition.id.lowercased()
            summary[key, default: 0] += item.quantity
        }
        return summary
    }

    /// 获取指定资源的数量
    /// - Parameter definitionId: 物品定义ID
    /// - Returns: 该资源的总数量
    func getResourceQuantity(for definitionId: String) -> Int {
        let normalizedId = definitionId.lowercased()
        return items
            .filter { $0.definition.id.lowercased() == normalizedId }
            .reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Resource Display Helpers (Day 29)
    
    /// 获取资源本地化显示名称（用于建筑系统 UI）
    /// - Note: 优先使用 ItemDefinition.name（本地化 key），否则使用 item_<id>，与 building_templates.json 的 ID 一致。
    func resourceDisplayName(for definitionId: String) -> String {
        let normalizedId = definitionId.lowercased()
        let locale = LanguageManager.shared.currentLocale
        if let definition = definitionsCache[normalizedId] {
            return String(localized: String.LocalizationValue(definition.name), locale: locale)
        }
        let key = "item_\(normalizedId)"
        return String(localized: String.LocalizationValue(key), locale: locale)
    }
    
    /// 获取资源图标（用于建筑系统 UI）
    /// - Note: 优先使用已加载的 ItemDefinition.icon，否则使用内置映射。
    func resourceIconName(for definitionId: String) -> String {
        let normalizedId = definitionId.lowercased()
        
        if let definition = definitionsCache[normalizedId] {
            return definition.icon
        }
        
        switch normalizedId {
        case "wood", "wood_plank":
            return "tree.fill"
        case "stone":
            return "square.stack.3d.up.fill"
        case "metal", "scrap_metal":
            return "gearshape.fill"
        case "fabric":
            return "scissors"
        case "glass":
            return "circle.grid.cross.fill"
        case "circuit", "electronic_parts":
            return "cpu.fill"
        default:
            return "cube.fill"
        }
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
    
    /// 确保建筑资源定义在 definitionsCache 中（ID 与 building_templates.json 的 wood/stone/fabric 等一致）
    /// 修复：添加所有可能的 ID 变体以处理遗留数据库数据（"wood", "item_wood", "Wood", "item_Wood" 等）
    private func ensureBuildingResourceDefinitions() {
        let buildingIds = ["wood", "stone", "metal", "fabric", "glass", "scrap_metal", "circuit", "concrete"]
        for id in buildingIds {
            let definition = ItemDefinition(
                id: id,
                name: "item_\(id)",
                description: "item_scrap_metal_desc",
                category: .material,
                icon: resourceIconName(for: id),
                rarity: .common
            )

            // 添加所有可能的 ID 变体到缓存（处理遗留 DB 数据）
            let variations = [
                id,                          // "wood"
                "item_\(id)",               // "item_wood"
                id.capitalized,             // "Wood"
                "item_\(id.capitalized)"    // "item_Wood"
            ]

            for variation in variations {
                if definitionsCache[variation] == nil {
                    definitionsCache[variation] = definition
                    #if DEBUG
                    print("📦 [DEBUG] Added resource definition: \(variation)")
                    #endif
                }
            }
        }
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
    
    private func seedDemoResourcesIfNeeded(userId: UUID) async {
#if DEBUG
        guard !isSeedingDemoResources else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: demoSeedKey) else { return }
        isSeedingDemoResources = true
        defer { isSeedingDemoResources = false }
        
        let resources: [(String, Int)] = [
            ("wood", 100),
            ("stone", 100)
        ]
        
        for (resourceId, quantity) in resources {
            let definition = ItemDefinition(
                id: resourceId,
                name: "item_\(resourceId)",
                description: "item_scrap_metal_desc",
                category: .material,
                icon: resourceIconName(for: resourceId),
                rarity: .common
            )
            definitionsCache[resourceId] = definition
            
            let item = CollectedItem(
                id: UUID(),
                definition: definition,
                quality: .good,
                foundDate: Date(),
                quantity: quantity
            )
            
            await addSingleItem(
                userId: userId,
                item: item,
                sourceType: "demo",
                sourceSessionId: nil
            )
        }
        
        defaults.set(true, forKey: demoSeedKey)
#endif
}
    
    // MARK: - Developer Tools (Phase 4)
    
    #if DEBUG
    /// 添加测试资源（ID 与 building_templates.json 一致：wood, stone, fabric, metal, glass）
    /// 供 BuildingBrowserView / TerritoryDetailView 的「添加测试材料」使用
    func addTestResources() async {
        let ids = ["wood", "stone", "fabric", "metal", "glass"]
        for id in ids {
            await addTestResource(resourceId: id, quantity: 500)
        }
        await loadItems()
        print("📦 [DEBUG] ✅ addTestResources: 已添加 wood, stone, fabric, metal, glass")
    }
    
    /// 添加单个测试资源，ID 必须与 building_templates.json 的 required_resources 完全一致
    func addTestResource(resourceId: String, quantity: Int) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        let sid = resourceId.lowercased()
        let testDefinition = ItemDefinition(
            id: sid,
            name: "item_\(sid)",
            description: "item_scrap_metal_desc",
            category: .material,
            icon: resourceIconName(for: sid),
            rarity: .common
        )
        definitionsCache[sid] = testDefinition
        let testItem = CollectedItem(
            id: UUID(),
            definition: testDefinition,
            quality: .good,
            foundDate: Date(),
            quantity: quantity
        )
        await addSingleItem(userId: userId, item: testItem, sourceType: "debug", sourceSessionId: nil)
    }
    
    /// 添加建筑测试资源包，ID 与 building_templates.json 的 required_resources 完全一致
    func addBuildingTestResources() async {
        let resources: [(String, Int)] = [
            ("wood", 500),
            ("stone", 500),
            ("metal", 200),
            ("fabric", 200),
            ("scrap_metal", 150),
            ("glass", 100),
            ("circuit", 50)
        ]
        for (resourceId, quantity) in resources {
            await addTestResource(resourceId: resourceId, quantity: quantity)
        }
        await loadItems()
        print("📦 [DEBUG] ✅ 建筑测试资源已注入（wood, stone, metal, fabric, scrap_metal, glass, circuit）")
    }
    #endif
}
  
