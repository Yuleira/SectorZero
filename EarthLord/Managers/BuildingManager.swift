//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  负责建筑模板加载、建造验证、资源消耗、升级等核心逻辑
//

import Foundation
import Supabase
import Combine
import CoreLocation

/// 建筑管理器
/// 负责建筑系统的核心业务逻辑
@MainActor
final class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布属性

    /// 建筑模板列表（从 JSON 加载）
    @Published private(set) var buildingTemplates: [BuildingTemplate] = []

    /// 玩家拥有的建筑列表
    @Published private(set) var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 模板缓存（templateId -> BuildingTemplate）
    private var templateCache: [String: BuildingTemplate] = [:]
    
    /// 进度更新定时器
    private var progressTimer: Timer?

    // MARK: - 初始化

    private init() {
        debugLog("🏗️ [建筑管理器] 初始化")
        startProgressTimer()
    }
    
    deinit {
        let timerToInvalidate = self.progressTimer
        // Use MainActor.assumeIsolated if you're certain deinit runs on main thread
        // Or simply invalidate directly if your class is @MainActor
        timerToInvalidate?.invalidate()
        debugLog("🏗️ [建筑] BuildingManager 已销毁")
    }

    // MARK: - 模板加载

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() async {
        debugLog("🏗️ [建筑] instance id=\(ObjectIdentifier(self))")
        debugLog("🏗️ [建筑] 开始加载建筑模板...")

        // 确保在 bundle 中找到文件
        let url = Bundle.main.url(forResource: "building_templates", withExtension: "json")
            ?? Bundle.main.url(forResource: "building_templates", withExtension: "json", subdirectory: "Resources")
        guard let url = url else {
            errorMessage = String(localized: "error_building_templates_not_found")
            debugLog("🏗️ [建筑] ❌ 文件不存在")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // 📋 重要：JSON 使用 snake_case，Swift 使用 camelCase
            // .convertFromSnakeCase 会自动将 template_id → templateId
            // 对于复杂映射（如 required_resources），BuildingTemplate.CodingKeys 手动处理
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let templates = try decoder.decode([BuildingTemplate].self, from: data)
            debugLog("🏗️ [建筑] 解码模板数: \(templates.count)")
            
            buildingTemplates = templates
            templateCache = Dictionary(uniqueKeysWithValues: templates.map { ($0.templateId, $0) })
            debugLog("🏗️ [建筑] 赋值后 templates: \(buildingTemplates.count)")
            
            debugLog("🏗️ [建筑] ✅ 成功加载 \(templates.count) 个建筑模板")
        } catch {
            errorMessage = String(localized: "error_load_building_templates_failed") + ": " + error.localizedDescription
            debugLog("🏗️ [建筑] ❌ 加载失败: \(error)")
        }
    }

    // MARK: - 建筑验证

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家当前资源汇总 [物品ID: 数量]
    /// - Returns: (是否可建造, 错误信息)
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> (canBuild: Bool, error: BuildingError?) {
        
        // 1. 检查资源是否足够：使用与 getResourceSummary 一致的归一化 ID（小写，如 "wood"/"stone"）查找库存
        var missingResources: [String: Int] = [:]

        #if DEBUG
        print("🏗️ [DEBUG] Resource validation for \(template.name):")
        print("  Player resources: \(playerResources)")
        #endif

        for (resourceId, required) in template.requiredResources {
            let normalizedId = resourceId.lowercased()
            let available = playerResources[normalizedId] ?? 0

            #if DEBUG
            print("  - Required: \(resourceId) (normalized: \(normalizedId)) x\(required)")
            print("    Available: \(available)")
            #endif

            if available < required {
                let shortage = required - available
                missingResources[resourceId] = shortage
                debugLog("🏗️ [建筑] ❌ 资源不足: \(resourceId)，需要 \(required)，拥有 \(available)，缺少 \(shortage)")
            } else {
                #if DEBUG
                print("    ✅ Sufficient")
                #endif
            }
        }
        
        if !missingResources.isEmpty {
            return (false, .insufficientResources(missing: missingResources))
        }
        
        // 2. 检查该领地内同类型建筑是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count
        
        if existingCount >= template.maxPerTerritory {
            debugLog("🏗️ [建筑] 达到上限: \(template.name) 在领地 \(territoryId) 中已有 \(existingCount) 个，上限 \(template.maxPerTerritory)")
            return (false, .maxBuildingsReached(maxAllowed: template.maxPerTerritory))
        }
        
        debugLog("🏗️ [建筑] ✅ 验证通过: 可以建造 \(template.name)")
        return (true, nil)
    }

    // MARK: - 建造操作

    /// 开始建造
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 建造结果
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async -> Result<PlayerBuilding, BuildingError> {
        
        // 1. 查找模板
        guard let template = templateCache[templateId] else {
            debugLog("🏗️ [建筑] ❌ 模板不存在: \(templateId)")
            return .failure(.templateNotFound)
        }
        
        debugLog("🏗️ [建筑] 开始建造: \(template.name)")
        
        // 2. 获取当前资源
        let playerResources = InventoryManager.shared.getResourceSummary()
        
        // 3. 验证是否可以建造
        let validation = canBuild(template: template, territoryId: territoryId, playerResources: playerResources)
        guard validation.canBuild else {
            debugLog("🏗️ [建筑] ❌ 验证失败")
            return .failure(validation.error ?? .templateNotFound)
        }
        
        // 4. 消耗资源（带回滚支持）
        var consumedResources: [(definitionId: String, amount: Int)] = []

        for (resourceId, amount) in template.requiredResources {
            let normalizedId = resourceId.lowercased()
            let success = await InventoryManager.shared.removeItemsByDefinition(
                definitionId: normalizedId,
                quantity: amount
            )

            if success {
                consumedResources.append((definitionId: normalizedId, amount: amount))
            } else {
                debugLog("🏗️ [建筑] ❌ 资源消耗失败: \(resourceId) x\(amount)，开始回滚...")
                for consumed in consumedResources {
                    let definition = ItemDefinition(
                        id: consumed.definitionId,
                        name: "item_\(consumed.definitionId)",
                        description: "item_scrap_metal_desc",
                        category: .material,
                        icon: InventoryManager.shared.resourceIconName(for: consumed.definitionId),
                        rarity: .common
                    )
                    let rollbackItem = CollectedItem(
                        definition: definition,
                        quality: .good,
                        foundDate: Date(),
                        quantity: consumed.amount
                    )
                    await InventoryManager.shared.addItems([rollbackItem], sourceType: "rollback")
                    debugLog("🏗️ [建筑] 🔄 回滚: 返还 \(consumed.definitionId) x\(consumed.amount)")
                }
                errorMessage = String(localized: "error_resource_consumption_failed")
                return .failure(.insufficientResources(missing: [resourceId: amount]))
            }
        }

        debugLog("🏗️ [建筑] ✅ 资源消耗成功")

        // 5. 获取当前用户
        guard let userId = AuthManager.shared.currentUser?.id else {
            debugLog("🏗️ [建筑] ❌ 未登录")
            errorMessage = String(localized: "error_not_logged_in")
            return .failure(.notAuthenticated)
        }
        
        // 6. 计算完成时间
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(TimeInterval(template.buildTimeSeconds))
        
        // 7. 构建插入数据
        let insertData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "territory_id": .string(territoryId),
            "template_id": .string(templateId),
            "building_name": .string(template.resolvedLocalizedName),
            "status": .string(BuildingStatus.constructing.rawValue),
            "level": .integer(1),
            "location_lat": location.map { .double($0.latitude) } ?? .null,
            "location_lon": location.map { .double($0.longitude) } ?? .null,
            "build_started_at": .string(startedAt.ISO8601Format()),
            "build_completed_at": .string(completedAt.ISO8601Format())
        ]
        
        // 8. 插入数据库
        do {
            let response: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .insert(insertData)
                .select()
                .execute()
                .value
            
            guard let newBuilding = response.first else {
                debugLog("🏗️ [建筑] ❌ 插入成功但未返回数据")
                return .failure(.templateNotFound)
            }
            
            // 9. 更新本地缓存
            playerBuildings.append(newBuilding)
            
            debugLog("🏗️ [建筑] ✅ 建造成功: \(template.name)，预计 \(template.buildTimeSeconds) 秒后完成")
            
            // 10. 启动倒计时（未来可以添加定时器自动转换状态）
            scheduleCompletion(buildingId: newBuilding.id, completionTime: completedAt)
            
            return .success(newBuilding)
            
        } catch {
            debugLog("🏗️ [建筑] ❌ 数据库插入失败: \(error.localizedDescription)")
            for consumed in consumedResources {
                let definition = ItemDefinition(
                    id: consumed.definitionId,
                    name: "item_\(consumed.definitionId)",
                    description: "item_scrap_metal_desc",
                    category: .material,
                    icon: InventoryManager.shared.resourceIconName(for: consumed.definitionId),
                    rarity: .common
                )
                let rollbackItem = CollectedItem(
                    definition: definition,
                    quality: .good,
                    foundDate: Date(),
                    quantity: consumed.amount
                )
                await InventoryManager.shared.addItems([rollbackItem], sourceType: "rollback")
                debugLog("🏗️ [建筑] 🔄 DB失败回滚: 返还 \(consumed.definitionId) x\(consumed.amount)")
            }
            errorMessage = String(localized: "error_construction_failed") + ": " + error.localizedDescription
            return .failure(.templateNotFound)
        }
    }

    // MARK: - 建筑完成

    /// 完成建造（将状态从 constructing 改为 active）
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 是否成功
    func completeConstruction(buildingId: UUID) async -> Bool {
        debugLog("🏗️ [建筑] 完成建造: \(buildingId)")
        
        do {
            // 更新数据库
            try await supabase
                .from("player_buildings")
                .update(["status": BuildingStatus.active.rawValue])
                .eq("id", value: buildingId.uuidString)
                .execute()
            
            // 更新本地缓存
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                var building = playerBuildings[index]
                building.status = .active
                playerBuildings[index] = building
            }
            
            debugLog("🏗️ [建筑] ✅ 建筑已激活")
            return true
            
        } catch {
            debugLog("🏗️ [建筑] ❌ 完成失败: \(error.localizedDescription)")
            errorMessage = String(localized: "error_complete_construction_failed") + ": " + error.localizedDescription
            return false
        }
    }

    // MARK: - 升级操作

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 升级结果
    func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        debugLog("🏗️ [建筑] 开始升级建筑: \(buildingId)")
        
        // 1. 查找建筑
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            debugLog("🏗️ [建筑] ❌ 建筑不存在")
            return .failure(.templateNotFound)
        }
        
        // 2. 检查状态（只有 active 状态才能升级）
        guard building.status == .active else {
            debugLog("🏗️ [建筑] ❌ 建筑状态不符合: \(building.status.rawValue)")
            return .failure(.invalidStatus)
        }
        
        // 3. 查找模板并检查等级上限
        guard let template = templateCache[building.templateId] else {
            debugLog("🏗️ [建筑] ❌ 模板不存在")
            return .failure(.templateNotFound)
        }
        
        guard building.level < template.maxLevel else {
            debugLog("🏗️ [建筑] ❌ 已达最大等级: \(building.level)/\(template.maxLevel)")
            return .failure(.invalidStatus) // 应创建 .maxLevelReached 错误
        }
        
        // 4. 执行升级（未来可以添加升级消耗资源逻辑）
        let newLevel = building.level + 1
        
        do {
            try await supabase
                .from("player_buildings")
                .update(["level": newLevel])
                .eq("id", value: buildingId.uuidString)
                .execute()
            
            // 更新本地缓存
            if let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                var updatedBuilding = playerBuildings[index]
                updatedBuilding.level = newLevel
                playerBuildings[index] = updatedBuilding
                
                debugLog("🏗️ [建筑] ✅ 升级成功: \(building.buildingName) Lv.\(building.level) -> Lv.\(newLevel)")
                return .success(updatedBuilding)
            }
            
            return .failure(.templateNotFound)
            
        } catch {
            debugLog("🏗️ [建筑] ❌ 升级失败: \(error.localizedDescription)")
            errorMessage = String(localized: "error_upgrade_failed") + ": " + error.localizedDescription
            return .failure(.templateNotFound)
        }
    }

    // MARK: - 拆除操作 (Day 29)

    /// 拆除建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 是否成功
    func demolishBuilding(buildingId: UUID) async -> Bool {
        debugLog("🏗️ [建筑] 开始拆除建筑: \(buildingId)")
        
        do {
            // 从数据库删除
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()
            
            // 从本地缓存移除
            playerBuildings.removeAll { $0.id == buildingId }
            
            debugLog("🏗️ [建筑] ✅ 拆除成功")
            return true
            
        } catch {
            debugLog("🏗️ [建筑] ❌ 拆除失败: \(error.localizedDescription)")
            errorMessage = String(localized: "error_demolish_failed") + ": " + error.localizedDescription
            return false
        }
    }

    // MARK: - 数据加载

    /// 加载玩家建筑
    /// - Parameter territoryId: 领地 ID（可选，不传则加载所有）
    func fetchPlayerBuildings(territoryId: String? = nil) async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            debugLog("🏗️ [建筑] 未登录")
            return
        }
        
        debugLog("🏗️ [建筑] 加载玩家建筑...")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var query = supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
            
            // 如果指定了领地，则过滤
            if let territoryId = territoryId {
                query = query.eq("territory_id", value: territoryId)
            }
            
            let buildings: [PlayerBuilding] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value
            
            playerBuildings = buildings
            
            debugLog("🏗️ [建筑] ✅ 加载了 \(buildings.count) 个建筑")
            
            // 检查是否有建筑需要自动完成
            await checkPendingCompletions()
            
        } catch {
            errorMessage = String(localized: "error_load_buildings_failed") + ": " + error.localizedDescription
            debugLog("🏗️ [建筑] ❌ 加载失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 辅助方法

    /// 根据 templateId 获取模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return templateCache[templateId]
    }

    /// 获取某领地内的建筑
    func getBuildings(for territoryId: String) -> [PlayerBuilding] {
        return playerBuildings.filter { $0.territoryId == territoryId }
    }

    /// 按分类获取模板
    func getTemplates(byCategory category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category }
    }

    /// 获取某领地内某模板的建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.templateId == templateId && $0.territoryId == territoryId
        }.count
    }

    // MARK: - 私有方法

    /// 调度建筑完成（定时器）
    private func scheduleCompletion(buildingId: UUID, completionTime: Date) {
        let timeInterval = completionTime.timeIntervalSinceNow
        
        guard timeInterval > 0 else {
            // 已经到时间了，立即完成
            Task {
                await completeConstruction(buildingId: buildingId)
            }
            return
        }
        
        debugLog("🏗️ [建筑] 定时器设置: \(Int(timeInterval)) 秒后完成")
        
        // 使用 Task.sleep 实现定时器
        Task {
            try? await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
            _ = await completeConstruction(buildingId: buildingId)
        }
    }

    /// 检查待完成的建筑（启动时调用）
    private func checkPendingCompletions() async {
        let now = Date()
        
        for building in playerBuildings {
            // 只处理 constructing 状态
            guard building.status == .constructing,
                  let completionTime = building.buildCompletedAt else {
                continue
            }
            
            if completionTime <= now {
                // 已经到时间，立即完成
                _ = await completeConstruction(buildingId: building.id)
            } else {
                // 尚未到时间，设置定时器
                scheduleCompletion(buildingId: building.id, completionTime: completionTime)
            }
        }
    }

    /// 清除缓存（用于切换用户时）
    func clearCache() {
        playerBuildings.removeAll()
        // buildingTemplates 不需要清除，因为是静态配置
    }
    
    // MARK: - Progress Timer (Phase 4)
    
    /// 启动进度更新定时器（每秒更新一次）
    private func startProgressTimer() {
        // 避免重复启动
        guard progressTimer == nil else { return }
        
        debugLog("🏗️ [建筑] 启动进度定时器")
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateBuildingProgress()
            }
        }
    }
    
    /// 停止进度定时器
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        debugLog("🏗️ [建筑] 停止进度定时器")
    }
    
    /// 更新建筑进度并触发 UI 刷新
    private func updateBuildingProgress() async {
        let now = Date()
        var hasChanges = false
        
        for (_, building) in playerBuildings.enumerated() {
            // 只处理 constructing 状态
            guard building.status == .constructing,
                  let completionTime = building.buildCompletedAt else {
                continue
            }
            
            // 检查是否已完成
            if completionTime <= now {
                // 自动完成建造
                _ = await completeConstruction(buildingId: building.id)
                hasChanges = true
            } else {
                // 触发 UI 更新（buildProgress 和 formattedRemainingTime 是计算属性）
                // 通过修改数组来触发 @Published 更新
                objectWillChange.send()
            }
        }
        
        if hasChanges {
            debugLog("🏗️ [建筑] 定时器检测到建筑完成")
        }
    }
}
