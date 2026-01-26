//
//  Territory.swift
//  EarthLord
//
//  Created by Claude on 07/01/2026.
//
//  领地数据模型
//  用于解析数据库返回的领地数据

import Foundation
import SwiftUI
import CoreLocation

/// 领地数据模型
struct Territory: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String?             // 可选，数据库允许为空
    var customName: String?       // 用户自定义名称
    let path: [[String: Double]]  // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?
    let isActive: Bool?
    let completedAt: String?      // 完成时间
    let startedAt: String?        // 开始时间
    let createdAt: String?        // 创建时间

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
    case name
    case customName = "custom_name"
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（如果没有名称则显示默认值）
    var displayName: LocalizedStringResource {
        if let custom = customName, !custom.isEmpty {
            // ✅ 修复：将 String 变量包装成资源类型
            return LocalizedStringResource(stringLiteral: custom)
        }
        // 如果名字是数据库默认的英文，或者为空，强制拦截并返回本地化钥匙
        // 使用 localizedCaseInsensitiveCompare 进行更健壮的匹配
        if let actualName = name, !actualName.isEmpty {
            if actualName.localizedCaseInsensitiveCompare("Unnamed Territory") == .orderedSame {
                return LocalizedString.unnamedTerritory
            }
            // 有实际名称，直接返回
            return LocalizedStringResource(stringLiteral: actualName)
        } else {
            // nil 或空字符串，返回本地化默认值
            return LocalizedString.unnamedTerritory
        }
    }

    /// 格式化完成时间
    var formattedCompletedAt: String? {
        guard let completedAt = completedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 尝试带毫秒解析
        if let date = formatter.date(from: completedAt) {
            return formatDate(date)
        }

        // 尝试不带毫秒解析
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: completedAt) {
            return formatDate(date)
        }

        return nil
    }

    /// 格式化日期为本地显示
    private func formatDate(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
}
