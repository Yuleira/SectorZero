//
//  CollisionModels.swift
//  EarthLord
//
//  Created by Claude on 08/01/2026.
//
//  碰撞检测相关的数据模型
//  包含预警级别、碰撞类型和检测结果

import Foundation

// MARK: - 预警级别

/// 预警级别枚举
/// 根据距离他人领地的远近划分不同级别
enum WarningLevel: Int {
    case safe = 0       // 安全（>100m）
    case caution = 1    // 注意（50-100m）- 黄色横幅
    case warning = 2    // 警告（25-50m）- 橙色横幅
    case danger = 3     // 危险（<25m）- 红色横幅
    case violation = 4  // 违规（已碰撞）- 红色横幅 + 停止圈地

    var description: String {
        switch self {
        case .safe: return String(localized: "warning_level_safe")
        case .caution: return String(localized: "warning_level_caution")
        case .warning: return String(localized: "warning_level_warning")
        case .danger: return String(localized: "warning_level_danger")
        case .violation: return String(localized: "warning_level_violation")
        }
    }
}

// MARK: - 碰撞类型

/// 碰撞类型枚举
/// 标识具体的碰撞原因
enum CollisionType {
    case pointInTerritory       // 点在他人领地内
    case pathCrossTerritory     // 路径穿越他人领地边界
    case selfIntersection       // 自相交（Day 17 已有）
}

// MARK: - 碰撞检测结果

/// 碰撞检测结果
/// 包含检测的所有相关信息
struct CollisionResult {
    let hasCollision: Bool          // 是否碰撞
    let collisionType: CollisionType?   // 碰撞类型
    let message: String?            // 提示消息
    let closestDistance: Double?    // 距离最近领地的距离（米）
    let warningLevel: WarningLevel  // 预警级别

    // 便捷构造器：安全状态
    static var safe: CollisionResult {
        CollisionResult(hasCollision: false, collisionType: nil, message: nil, closestDistance: nil, warningLevel: .safe)
    }
}
