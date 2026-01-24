//
//  ExplorationReward.swift
//  EarthLord
//
//  探索奖励相关模型
//

import Foundation
import SwiftUI

// MARK: - 探索奖励等级

/// 探索奖励等级
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"          // 无奖励 (< 200m)
    case bronze = "bronze"      // 铜级 (200-500m)
    case silver = "silver"      // 银级 (500-1000m)
    case gold = "gold"          // 金级 (1000-2000m)
    case diamond = "diamond"    // 钻石级 (> 2000m)

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .none: return String(localized: "reward_tier_none")
        case .bronze: return String(localized: "reward_tier_bronze")
        case .silver: return String(localized: "reward_tier_silver")
        case .gold: return String(localized: "reward_tier_gold")
        case .diamond: return String(localized: "reward_tier_diamond")
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "star.circle.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 显示颜色
    var color: Color {
        switch self {
        case .none: return .gray
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)  // 铜色
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)  // 银色
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)  // 金色
        case .diamond: return Color(red: 0.5, green: 0.8, blue: 1.0)  // 钻石蓝
        }
    }

    /// 奖励物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 稀有度概率分布 [common, rare, epic]
    var rarityProbabilities: [Double] {
        switch self {
        case .none: return [1.0, 0.0, 0.0]
        case .bronze: return [0.90, 0.10, 0.00]   // 90% 普通, 10% 稀有
        case .silver: return [0.70, 0.25, 0.05]   // 70% 普通, 25% 稀有, 5% 史诗
        case .gold: return [0.50, 0.35, 0.15]     // 50% 普通, 35% 稀有, 15% 史诗
        case .diamond: return [0.30, 0.40, 0.30]  // 30% 普通, 40% 稀有, 30% 史诗
        }
    }

    /// 最小距离要求（米）
    var minDistance: Double {
        switch self {
        case .none: return 0
        case .bronze: return 200
        case .silver: return 500
        case .gold: return 1000
        case .diamond: return 2000
        }
    }

    /// 根据距离计算奖励等级
    static func from(distance: Double) -> RewardTier {
        switch distance {
        case 2000...: return .diamond
        case 1000..<2000: return .gold
        case 500..<1000: return .silver
        case 200..<500: return .bronze
        default: return .none
        }
    }
}

// MARK: - 探索会话数据模型（与数据库对应）

struct ExplorationSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let totalDistance: Double
    let rawDistance: Double?
    let pointCount: Int
    let rewardTier: String
    let itemsCount: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case totalDistance = "total_distance"
        case rawDistance = "raw_distance"
        case pointCount = "point_count"
        case rewardTier = "reward_tier"
        case itemsCount = "items_count"
        case createdAt = "created_at"
    }

    var tier: RewardTier {
        RewardTier(rawValue: rewardTier) ?? .none
    }

    /// 格式化的时长字符串
    var durationString: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化的距离字符串
    var distanceString: String {
        if totalDistance >= 1000 {
            return String(format: "%.2f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }
}

// MARK: - 探索状态

/// 探索状态枚举
enum ExplorationState: Equatable {
    case idle           // 空闲
    case exploring      // 探索中
    case processing     // 处理中（计算奖励）
    case completed      // 完成
    case failed(String) // 失败

    static func == (lhs: ExplorationState, rhs: ExplorationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.exploring, .exploring),
             (.processing, .processing),
             (.completed, .completed):
            return true
        case let (.failed(msg1), .failed(msg2)):
            return msg1 == msg2
        default:
            return false
        }
    }
}
