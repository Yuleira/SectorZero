//
//  BuildingModels.swift
//  EarthLord
//
//  建筑系统数据模型
//  遵循 iOS 命名规范：Swift 属性使用 camelCase，数据库/JSON 使用 snake_case
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Building Category

enum BuildingCategory: String, Codable, CaseIterable {
    case survival
    case storage
    case production
    case energy

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .survival:
            return String(localized: "category_survival")
        case .storage:
            return String(localized: "category_storage")
        case .production:
            return String(localized: "category_production")
        case .energy:
            return String(localized: "category_energy")
        }
    }

    var iconName: String {
        switch self {
        case .survival:
            return "house.fill"
        case .storage:
            return "archivebox.fill"
        case .production:
            return "hammer.fill"
        case .energy:
            return "bolt.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .survival:
            return .orange
        case .storage:
            return .brown
        case .production:
            return .indigo
        case .energy:
            return .yellow
        }
    }
}

// MARK: - Building Status

enum BuildingStatus: String, Codable {
    case constructing
    case active

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .constructing:
            return String(localized: "status_constructing")
        case .active:
            return String(localized: "status_active")
        }
    }

    var accentColor: Color {
        switch self {
        case .constructing:
            return .cyan
        case .active:
            return .green
        }
    }
}

// MARK: - Building Template

/// 建筑模板（定义可建造的建筑类型）
/// Swift 属性使用 camelCase，通过 CodingKeys 映射到 JSON 的 snake_case
struct BuildingTemplate: Identifiable, Codable {
    let id: UUID
    let templateId: String
    let name: String // 本地化 key
    let category: BuildingCategory
    let tier: Int
    let description: String // 本地化 key
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    init(
        id: UUID,
        templateId: String,
        name: String,
        category: BuildingCategory,
        tier: Int,
        description: String,
        icon: String,
        requiredResources: [String: Int],
        buildTimeSeconds: Int,
        maxPerTerritory: Int,
        maxLevel: Int
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.category = category
        self.tier = tier
        self.description = description
        self.icon = icon
        self.requiredResources = requiredResources
        self.buildTimeSeconds = buildTimeSeconds
        self.maxPerTerritory = maxPerTerritory
        self.maxLevel = maxLevel
    }

    var localizedName: String {
        NSLocalizedString(name, comment: "")
    }

    var localizedDescription: String {
        NSLocalizedString(description, comment: "")
    }

    /// CodingKeys 映射：兼容 snake_case / camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case templateIdSnake = "template_id"
        case templateIdCamel = "templateId"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResourcesSnake = "required_resources"
        case requiredResourcesCamel = "requiredResources"
        case buildTimeSecondsSnake = "build_time_seconds"
        case buildTimeSecondsCamel = "buildTimeSeconds"
        case maxPerTerritorySnake = "max_per_territory"
        case maxPerTerritoryCamel = "maxPerTerritory"
        case maxLevelSnake = "max_level"
        case maxLevelCamel = "maxLevel"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(BuildingCategory.self, forKey: .category)
        tier = try container.decode(Int.self, forKey: .tier)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)

        if let templateId = try container.decodeIfPresent(String.self, forKey: .templateIdSnake) {
            self.templateId = templateId
        } else if let templateId = try container.decodeIfPresent(String.self, forKey: .templateIdCamel) {
            self.templateId = templateId
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.templateIdSnake,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Missing template_id/templateId")
            )
        }

        if let required = try container.decodeIfPresent([String: Int].self, forKey: .requiredResourcesSnake) {
            requiredResources = required
        } else if let required = try container.decodeIfPresent([String: Int].self, forKey: .requiredResourcesCamel) {
            requiredResources = required
        } else {
            requiredResources = [:]
        }

        if let value = try container.decodeIfPresent(Int.self, forKey: .buildTimeSecondsSnake) {
            buildTimeSeconds = value
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .buildTimeSecondsCamel) {
            buildTimeSeconds = value
        } else {
            buildTimeSeconds = 0
        }

        if let value = try container.decodeIfPresent(Int.self, forKey: .maxPerTerritorySnake) {
            maxPerTerritory = value
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .maxPerTerritoryCamel) {
            maxPerTerritory = value
        } else {
            maxPerTerritory = 0
        }

        if let value = try container.decodeIfPresent(Int.self, forKey: .maxLevelSnake) {
            maxLevel = value
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .maxLevelCamel) {
            maxLevel = value
        } else {
            maxLevel = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(templateId, forKey: .templateIdSnake)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(tier, forKey: .tier)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(requiredResources, forKey: .requiredResourcesSnake)
        try container.encode(buildTimeSeconds, forKey: .buildTimeSecondsSnake)
        try container.encode(maxPerTerritory, forKey: .maxPerTerritorySnake)
        try container.encode(maxLevel, forKey: .maxLevelSnake)
    }
}

// MARK: - Player Building

/// 玩家拥有的建筑实例
/// Swift 属性使用 camelCase，通过 CodingKeys 映射到 Supabase 的 snake_case
struct PlayerBuilding: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?

    /// CodingKeys 映射：Swift camelCase ↔ Supabase snake_case
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
    }
    
    // MARK: - Computed Properties (Day 29 Extensions)
    
    /// 建筑坐标（如果已设置）
    /// ⚠️ 重要：数据库存储的是 GCJ-02 坐标，直接使用，不要再次转换！
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// 建造进度（0.0 - 1.0）
    var buildProgress: Double {
        guard status == .constructing,
              let completedAt = buildCompletedAt else {
            return status == .active ? 1.0 : 0.0
        }
        
        let totalTime = completedAt.timeIntervalSince(buildStartedAt)
        let elapsedTime = Date().timeIntervalSince(buildStartedAt)
        
        return min(max(elapsedTime / totalTime, 0.0), 1.0)
    }
    
    /// 剩余建造时间（格式化字符串）
    var formattedRemainingTime: String {
        guard status == .constructing,
              let completedAt = buildCompletedAt else {
            return ""
        }
        
        let remaining = completedAt.timeIntervalSinceNow
        
        if remaining <= 0 {
            return NSLocalizedString("building_completing", comment: "建筑状态")
        }
        
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Building Error

/// 建筑系统错误类型
enum BuildingError: Error {
    case insufficientResources(missing: [String: Int])
    case maxBuildingsReached(maxAllowed: Int)
    case invalidStatus
    case templateNotFound
    case notAuthenticated
    
    /// 本地化错误描述
    var localizedDescription: String {
        switch self {
        case .insufficientResources(let missing):
            let resourceList = missing.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return String(format: String(localized: "error_insufficient_resources"), resourceList)
        case .maxBuildingsReached(let max):
            return String(format: String(localized: "error_max_buildings_reached"), max)
        case .invalidStatus:
            return String(localized: "error_invalid_status")
        case .templateNotFound:
            return String(localized: "error_template_not_found")
        case .notAuthenticated:
            return String(localized: "error_not_authenticated")
        }
    }
}
// MARK: - Building Annotation
/// 建筑标注类
class BuildingAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let building: PlayerBuilding
    let template: BuildingTemplate?
    
    var title: String? {
        template?.localizedName ?? building.buildingName
    }
    
    var subtitle: String? {
        if building.status == .constructing {
            return String(localized: "status_constructing")
        } else {
            return String(localized: "building_level_format \(building.level)")
        }
    }
    
    init(coordinate: CLLocationCoordinate2D, building: PlayerBuilding, template: BuildingTemplate?) {
        self.coordinate = coordinate
        self.building = building
        self.template = template
        super.init()
    }
}
