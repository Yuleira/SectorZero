//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Claude on 07/01/2026.
//
//  领地管理器
//  负责领地数据的上传和拉取

import Foundation
import CoreLocation
import Combine
import Supabase

/// 领地管理器
/// 负责领地数据的上传和拉取
@MainActor
final class TerritoryManager: ObservableObject {

    // MARK: - 单例
    static let shared = TerritoryManager()

    // MARK: - 发布属性

    /// 所有领地数据
    @Published private(set) var territories: [Territory] = []

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转为 WKT 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 字符串，如 SRID=4326;POLYGON((lon lat, ...))
    /// - Note: WKT 格式是「经度在前，纬度在后」，多边形必须闭合
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else { return "" }

        var coords = coordinates

        // 确保多边形闭合（首尾相同）
        if let first = coords.first, let last = coords.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                coords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointStrings = coords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        return "SRID=4326;POLYGON((\(pointStrings.joined(separator: ", "))))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传方法

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 坐标数组
    ///   - area: 面积（平方米）
    ///   - startTime: 开始时间
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 获取当前用户
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // 构建上传数据
        let territoryData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "path": .array(pathJSON.map { dict in
                .object(dict.mapValues { .double($0) })
            }),
            "polygon": .string(wktPolygon),
            "bbox_min_lat": .double(bbox.minLat),
            "bbox_max_lat": .double(bbox.maxLat),
            "bbox_min_lon": .double(bbox.minLon),
            "bbox_max_lon": .double(bbox.maxLon),
            "area": .double(area),
            "point_count": .integer(coordinates.count),
            "started_at": .string(startTime.ISO8601Format()),
            "completed_at": .string(Date().ISO8601Format()),
            "is_active": .bool(true)
        ]

        print("📤 [领地上传] 开始上传，点数: \(coordinates.count), 面积: \(String(format: "%.0f", area))m²")

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("📤 [领地上传] ✅ 上传成功")
            TerritoryLogger.shared.log("领地上传成功，面积: \(String(format: "%.0f", area))m²", type: .success)
        } catch {
            print("📤 [领地上传] ❌ 上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw TerritoryError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - 拉取方法

    /// 加载所有有效领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 [领地加载] 开始加载所有领地...")

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            print("📥 [领地加载] ✅ 加载完成，共 \(response.count) 个领地")
            return response
        } catch {
            print("📥 [领地加载] ❌ 加载失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    /// 加载当前用户的领地
    /// - Returns: 领地数组
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        print("📥 [领地加载] 开始加载我的领地...")

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("📥 [领地加载] ✅ 加载完成，共 \(response.count) 个我的领地")
            return response
        } catch {
            print("📥 [领地加载] ❌ 加载我的领地失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - 删除方法

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        print("🗑️ [领地删除] 开始删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("🗑️ [领地删除] ✅ 删除成功")
            TerritoryLogger.shared.log("领地删除成功", type: .success)
            return true
        } catch {
            print("🗑️ [领地删除] ❌ 删除失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地删除失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录，请先登录"
        case .invalidCoordinates:
            return "坐标数据无效"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }
    }
}
