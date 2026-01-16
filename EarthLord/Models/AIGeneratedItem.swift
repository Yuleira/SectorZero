//
//  AIGeneratedItem.swift
//  EarthLord
//
//  AI 生成物品相关数据模型
//  用于与 Edge Function 通信
//

import Foundation

// MARK: - AI Generated Item

/// AI 生成的物品
struct AIGeneratedItem: Codable {
    /// 独特的物品名称
    let name: String

    /// 物品分类（医疗/食物/工具/武器/材料/水/其他）
    let category: String

    /// 稀有度（common/uncommon/rare/epic/legendary）
    let rarity: String

    /// 背景故事
    let story: String

    /// 转换为 ItemCategory 枚举
    /// 支持英文和中文类别名称，大小写不敏感
    var itemCategory: ItemCategory {
        let normalized = category.lowercased().trimmingCharacters(in: .whitespaces)
        switch normalized {
        case "medical", "医疗": return .medical
        case "food", "食物": return .food
        case "tool", "工具": return .tool
        case "weapon", "武器": return .weapon
        case "material", "材料": return .material
        case "water", "水": return .water
        default: return .other
        }
    }

    /// 转换为 ItemRarity 枚举
    var itemRarity: ItemRarity {
        return ItemRarity(rawValue: rarity) ?? .common
    }
}

// MARK: - Request Models

/// 生成物品请求
struct GenerateItemRequest: Codable {
    let poi: POIInfo
    let itemCount: Int
}

/// POI 信息（用于请求）
struct POIInfo: Codable {
    let name: String
    let type: String
    let dangerLevel: Int
}

// MARK: - Response Models

/// 生成物品响应
struct GenerateItemResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}
