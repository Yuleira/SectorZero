//
//  DensityLevel.swift
//  EarthLord
//
//  玩家密度等级枚举
//  根据附近玩家数量决定 POI 显示策略
//

import Foundation

/// 玩家密度等级
/// 用于根据附近玩家数量动态调整 POI 显示数量
enum DensityLevel: String, CaseIterable {
    /// 独行者：附近无其他玩家
    case alone = "alone"
    /// 低密度：1-5 人
    case low = "low"
    /// 中密度：6-20 人
    case medium = "medium"
    /// 高密度：20 人以上
    case high = "high"

    /// 根据附近玩家数量确定密度等级
    /// - Parameter count: 附近玩家数量（不含自己）
    /// - Returns: 对应的密度等级
    static func from(playerCount count: Int) -> DensityLevel {
        switch count {
        case 0:
            return .alone
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 该密度等级下最多显示的 POI 数量
    var maxPOICount: Int {
        switch self {
        case .alone:
            return 1
        case .low:
            return 3
        case .medium:
            return 6
        case .high:
            return 20  // 显示所有（受地理围栏限制）
        }
    }

    /// 本地化显示名称（Late-Binding: 返回 LocalizedStringResource）
    var localizedName: LocalizedStringResource {
        switch self {
        case .alone:
            return "density_alone"
        case .low:
            return "density_low"
        case .medium:
            return "density_medium"
        case .high:
            return "density_high"
        }
    }

    /// 密度等级描述
    var description: String {
        switch self {
        case .alone:
            return String(localized: "density_alone_desc", defaultValue: "附近没有其他幸存者")
        case .low:
            return String(localized: "density_low_desc", defaultValue: "附近有少量幸存者")
        case .medium:
            return String(localized: "density_medium_desc", defaultValue: "附近有一些幸存者")
        case .high:
            return String(localized: "density_high_desc", defaultValue: "附近有很多幸存者")
        }
    }
}
