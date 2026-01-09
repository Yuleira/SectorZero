//
//  MockExplorationData.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  探索模块测试假数据
//  用于开发阶段 UI 预览和功能测试
//

import Foundation
import CoreLocation

// MARK: - 物品稀有度

/// 物品稀有度枚举
/// 影响物品的掉落概率和价值
enum ItemRarity: String, CaseIterable {
    case common = "普通"      // 白色
    case uncommon = "优质"    // 绿色
    case rare = "稀有"        // 蓝色
    case epic = "史诗"        // 紫色
    case legendary = "传说"   // 橙色
}

// MARK: - 物品分类

/// 物品分类枚举
/// 用于背包分类显示和筛选
enum ItemCategory: String, CaseIterable {
    case water = "水"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
    case other = "其他"
}

// MARK: - 物品品质

/// 物品品质枚举
/// 表示物品的新旧/完好程度（部分物品无品质）
enum ItemQuality: String, CaseIterable {
    case pristine = "崭新"    // 100% 效果
    case good = "良好"        // 80% 效果
    case worn = "磨损"        // 60% 效果
    case damaged = "破损"     // 40% 效果
    case ruined = "报废"      // 20% 效果
}

// MARK: - 物品定义

/// 物品定义结构体
/// 记录物品的基础属性（不含数量和品质）
struct ItemDefinition: Identifiable {
    let id: String                  // 物品唯一标识
    let name: String                // 中文名称
    let category: ItemCategory      // 物品分类
    let weight: Double              // 单位重量（kg）
    let volume: Double              // 单位体积（L）
    let rarity: ItemRarity          // 稀有度
    let hasQuality: Bool            // 是否有品质属性
    let description: String         // 物品描述
    let icon: String                // SF Symbol 图标名
}

// MARK: - 背包物品

/// 背包物品结构体
/// 玩家拥有的具体物品实例
struct InventoryItem: Identifiable {
    let id: String                  // 实例唯一ID
    let itemId: String              // 物品定义ID
    var quantity: Int               // 数量
    let quality: ItemQuality?       // 品质（可选）
    let obtainedAt: Date            // 获得时间
    let obtainedLocation: String?   // 获得地点（可选）
}

// MARK: - POI 状态

/// 兴趣点状态枚举
enum POIStatus: String {
    case undiscovered = "未发现"    // 地图上不显示
    case discovered = "已发现"      // 地图上显示，可探索
    case hasLoot = "有物资"         // 已探索，有物资可拾取
    case looted = "已搜空"          // 已探索，物资已被拾取
    case dangerous = "危险"         // 有威胁，需要谨慎
}

// MARK: - POI 类型

/// 兴趣点类型枚举
enum POIType: String {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case residence = "住宅"
    case office = "办公楼"
    case school = "学校"
    case police = "警察局"
}

// MARK: - 兴趣点

/// 兴趣点结构体
/// 地图上可探索的地点
struct ExplorationPOI: Identifiable {
    let id: String                          // 唯一标识
    let name: String                        // 地点名称
    let type: POIType                       // 地点类型
    var status: POIStatus                   // 当前状态
    let coordinate: CLLocationCoordinate2D  // 地理坐标
    let discoveredAt: Date?                 // 发现时间
    let lastVisitedAt: Date?                // 上次访问时间
    let dangerLevel: Int                    // 危险等级 (0-5)
    let lootProbability: Double             // 物资刷新概率 (0-1)
    let description: String                 // 地点描述
}

// MARK: - 探索结果

/// 单次探索结果结构体
/// 记录一次探索活动的统计数据
struct ExplorationResult: Identifiable {
    let id: String                          // 唯一标识
    let startTime: Date                     // 开始时间
    let endTime: Date                       // 结束时间
    let distanceWalked: Double              // 行走距离（米）
    let areaExplored: Double                // 探索面积（平方米）
    let poisDiscovered: Int                 // 发现的POI数量
    let itemsCollected: [CollectedItem]     // 收集的物品
    let experienceGained: Int               // 获得经验值
}

/// 收集的物品（探索结果中使用）
struct CollectedItem: Identifiable {
    let id: String
    let itemId: String
    let quantity: Int
    let quality: ItemQuality?
}

// MARK: - 探索统计

/// 玩家探索统计数据
struct ExplorationStats {
    let totalDistance: Double               // 累计行走距离（米）
    let totalArea: Double                   // 累计探索面积（平方米）
    let totalTime: TimeInterval             // 累计探索时长（秒）
    let poisDiscovered: Int                 // 发现的POI总数
    let itemsCollected: Int                 // 收集的物品总数
    let distanceRank: Int                   // 行走距离排名
    let areaRank: Int                       // 探索面积排名
}

// MARK: - 假数据

/// 探索模块假数据
/// 用于开发阶段 UI 预览和功能测试
struct MockExplorationData {

    // MARK: - 物品定义表

    /// 所有物品的定义
    /// 作为物品的基础数据字典
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "末日必需品，干净的饮用水",
            icon: "drop.fill"
        ),
        ItemDefinition(
            id: "water_purified",
            name: "净化水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .uncommon,
            hasQuality: false,
            description: "经过特殊净化处理的水，更加安全",
            icon: "drop.circle.fill"
        ),

        // 食物类
        ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            hasQuality: true,
            description: "保质期很长的罐头，末日生存必备",
            icon: "takeoutbag.and.cup.and.straw.fill"
        ),
        ItemDefinition(
            id: "energy_bar",
            name: "能量棒",
            category: .food,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: false,
            description: "高热量压缩食品，便于携带",
            icon: "bolt.fill"
        ),
        ItemDefinition(
            id: "mre",
            name: "军用口粮",
            category: .food,
            weight: 0.6,
            volume: 0.4,
            rarity: .rare,
            hasQuality: true,
            description: "军队标准即食口粮，营养均衡",
            icon: "bag.fill"
        ),

        // 医疗类
        ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            hasQuality: true,
            description: "基础医疗用品，用于包扎伤口",
            icon: "bandage.fill"
        ),
        ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: true,
            description: "通用药品，可治疗轻度疾病",
            icon: "pills.fill"
        ),
        ItemDefinition(
            id: "first_aid_kit",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.5,
            rarity: .rare,
            hasQuality: true,
            description: "完整的急救用品套装",
            icon: "cross.case.fill"
        ),
        ItemDefinition(
            id: "antibiotics",
            name: "抗生素",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .epic,
            hasQuality: true,
            description: "珍贵的抗生素，可治疗感染",
            icon: "pill.fill"
        ),

        // 材料类
        ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 1.5,
            rarity: .common,
            hasQuality: true,
            description: "基础建筑材料，用途广泛",
            icon: "tree.fill"
        ),
        ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "可回收的金属废料，用于制造",
            icon: "gearshape.fill"
        ),
        ItemDefinition(
            id: "electronic_parts",
            name: "电子元件",
            category: .material,
            weight: 0.2,
            volume: 0.1,
            rarity: .uncommon,
            hasQuality: true,
            description: "各种电子零件，用于修理设备",
            icon: "cpu.fill"
        ),
        ItemDefinition(
            id: "fuel",
            name: "燃料",
            category: .material,
            weight: 1.0,
            volume: 1.0,
            rarity: .rare,
            hasQuality: false,
            description: "珍贵的液体燃料",
            icon: "fuelpump.fill"
        ),

        // 工具类
        ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.15,
            rarity: .common,
            hasQuality: true,
            description: "便携照明工具，夜间探索必备",
            icon: "flashlight.on.fill"
        ),
        ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            hasQuality: true,
            description: "结实的尼龙绳，用途多样",
            icon: "lasso"
        ),
        ItemDefinition(
            id: "lockpick",
            name: "撬锁工具",
            category: .tool,
            weight: 0.1,
            volume: 0.02,
            rarity: .uncommon,
            hasQuality: true,
            description: "可以打开简单的锁",
            icon: "key.fill"
        ),
        ItemDefinition(
            id: "multitool",
            name: "多功能工具",
            category: .tool,
            weight: 0.2,
            volume: 0.05,
            rarity: .rare,
            hasQuality: true,
            description: "集成多种功能的便携工具",
            icon: "wrench.and.screwdriver.fill"
        )
    ]

    // MARK: - POI 列表

    /// 测试用 POI 列表
    /// 包含5个不同状态的兴趣点
    static let pois: [ExplorationPOI] = [
        // 废弃超市：已发现，有物资
        ExplorationPOI(
            id: "poi_supermarket_001",
            name: "废弃超市",
            type: .supermarket,
            status: .hasLoot,
            coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            discoveredAt: Date().addingTimeInterval(-86400 * 3),  // 3天前发现
            lastVisitedAt: Date().addingTimeInterval(-3600),       // 1小时前访问
            dangerLevel: 2,
            lootProbability: 0.7,
            description: "一家废弃的大型超市，货架上可能还有一些物资"
        ),

        // 医院废墟：已发现，已被搜空
        ExplorationPOI(
            id: "poi_hospital_001",
            name: "医院废墟",
            type: .hospital,
            status: .looted,
            coordinate: CLLocationCoordinate2D(latitude: 31.2354, longitude: 121.4787),
            discoveredAt: Date().addingTimeInterval(-86400 * 7),  // 7天前发现
            lastVisitedAt: Date().addingTimeInterval(-86400),      // 1天前访问
            dangerLevel: 4,
            lootProbability: 0.3,
            description: "曾经的医院，现在已是废墟。大部分医疗物资已被搜走"
        ),

        // 加油站：未发现
        ExplorationPOI(
            id: "poi_gas_001",
            name: "加油站",
            type: .gasStation,
            status: .undiscovered,
            coordinate: CLLocationCoordinate2D(latitude: 31.2284, longitude: 121.4817),
            discoveredAt: nil,
            lastVisitedAt: nil,
            dangerLevel: 1,
            lootProbability: 0.5,
            description: "路边的加油站，可能还有燃料"
        ),

        // 药店废墟：已发现，有物资
        ExplorationPOI(
            id: "poi_pharmacy_001",
            name: "药店废墟",
            type: .pharmacy,
            status: .hasLoot,
            coordinate: CLLocationCoordinate2D(latitude: 31.2324, longitude: 121.4707),
            discoveredAt: Date().addingTimeInterval(-86400 * 2),  // 2天前发现
            lastVisitedAt: Date().addingTimeInterval(-7200),       // 2小时前访问
            dangerLevel: 2,
            lootProbability: 0.6,
            description: "小型药店，玻璃门已破碎，里面可能还有药品"
        ),

        // 工厂废墟：未发现
        ExplorationPOI(
            id: "poi_factory_001",
            name: "工厂废墟",
            type: .factory,
            status: .undiscovered,
            coordinate: CLLocationCoordinate2D(latitude: 31.2264, longitude: 121.4757),
            discoveredAt: nil,
            lastVisitedAt: nil,
            dangerLevel: 3,
            lootProbability: 0.4,
            description: "废弃的工厂，可能有原材料和工具"
        )
    ]

    // MARK: - 背包物品

    /// 测试用背包物品列表
    /// 包含6-8种不同类型的物品
    static let inventoryItems: [InventoryItem] = [
        // 矿泉水 x 5（无品质）
        InventoryItem(
            id: "inv_001",
            itemId: "water_bottle",
            quantity: 5,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600),
            obtainedLocation: "废弃超市"
        ),

        // 罐头食品 x 3（良好品质）
        InventoryItem(
            id: "inv_002",
            itemId: "canned_food",
            quantity: 3,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-7200),
            obtainedLocation: "废弃超市"
        ),

        // 绷带 x 8（崭新品质）
        InventoryItem(
            id: "inv_003",
            itemId: "bandage",
            quantity: 8,
            quality: .pristine,
            obtainedAt: Date().addingTimeInterval(-86400),
            obtainedLocation: "药店废墟"
        ),

        // 药品 x 2（磨损品质）
        InventoryItem(
            id: "inv_004",
            itemId: "medicine",
            quantity: 2,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-86400),
            obtainedLocation: "药店废墟"
        ),

        // 木材 x 10（良好品质）
        InventoryItem(
            id: "inv_005",
            itemId: "wood",
            quantity: 10,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-172800),
            obtainedLocation: "工厂废墟"
        ),

        // 废金属 x 15（无品质）
        InventoryItem(
            id: "inv_006",
            itemId: "scrap_metal",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-172800),
            obtainedLocation: "工厂废墟"
        ),

        // 手电筒 x 1（磨损品质）
        InventoryItem(
            id: "inv_007",
            itemId: "flashlight",
            quantity: 1,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-259200),
            obtainedLocation: "医院废墟"
        ),

        // 绳子 x 2（良好品质）
        InventoryItem(
            id: "inv_008",
            itemId: "rope",
            quantity: 2,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-259200),
            obtainedLocation: "工厂废墟"
        )
    ]

    // MARK: - 探索结果示例

    /// 单次探索结果示例
    /// 模拟一次30分钟的探索活动
    static let sampleExplorationResult = ExplorationResult(
        id: "exp_001",
        startTime: Date().addingTimeInterval(-1800),  // 30分钟前开始
        endTime: Date(),                               // 现在结束
        distanceWalked: 2500,                          // 行走2500米
        areaExplored: 50000,                           // 探索5万平方米
        poisDiscovered: 1,                             // 发现1个POI
        itemsCollected: [
            CollectedItem(id: "col_001", itemId: "wood", quantity: 5, quality: .good),
            CollectedItem(id: "col_002", itemId: "water_bottle", quantity: 3, quality: nil),
            CollectedItem(id: "col_003", itemId: "canned_food", quantity: 2, quality: .good)
        ],
        experienceGained: 150                          // 获得150经验
    )

    // MARK: - 探索统计示例

    /// 玩家探索统计数据示例
    static let sampleExplorationStats = ExplorationStats(
        totalDistance: 15000,      // 累计行走15000米（15公里）
        totalArea: 250000,         // 累计探索25万平方米
        totalTime: 36000,          // 累计探索10小时（36000秒）
        poisDiscovered: 12,        // 发现12个POI
        itemsCollected: 156,       // 收集156个物品
        distanceRank: 42,          // 行走距离排名第42
        areaRank: 38               // 探索面积排名第38
    )

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(by itemId: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == itemId }
    }

    /// 根据分类筛选物品定义
    static func getItemDefinitions(by category: ItemCategory) -> [ItemDefinition] {
        return itemDefinitions.filter { $0.category == category }
    }

    /// 根据稀有度筛选物品定义
    static func getItemDefinitions(by rarity: ItemRarity) -> [ItemDefinition] {
        return itemDefinitions.filter { $0.rarity == rarity }
    }

    /// 计算背包总重量
    static func calculateTotalWeight(items: [InventoryItem]) -> Double {
        var totalWeight: Double = 0
        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    static func calculateTotalVolume(items: [InventoryItem]) -> Double {
        var totalVolume: Double = 0
        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }

    /// 格式化距离显示
    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积显示
    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 1000000 {
            return String(format: "%.2f km²", squareMeters / 1000000)
        } else if squareMeters >= 10000 {
            return String(format: "%.1f 万m²", squareMeters / 10000)
        } else {
            return String(format: "%.0f m²", squareMeters)
        }
    }

    /// 格式化时长显示
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
