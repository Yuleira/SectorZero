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

/// RPC params for atomic distance increment
private nonisolated(unsafe) struct IncrementDistanceParams: Encodable, Sendable {
    nonisolated let p_user_id: String
    nonisolated let p_delta: Double
}

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

    /// 累计行走总距离（米）
    @Published private(set) var totalDistanceWalked: Double = 0

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
    ///   - distanceWalked: 行走距离（米）
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date, distanceWalked: Double = 0) async throws {
        // 获取当前用户
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        // Entitlement: territory limit by membership tier (Pioneer/Archon get higher limits)
        let maxAllowed = StoreKitManager.shared.currentMembershipTier.maxTerritories
        struct TerritoryIdRow: Decodable { let id: String }
        let existing: [TerritoryIdRow] = try await supabase
            .from("territories")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value
        if existing.count >= maxAllowed {
            throw TerritoryError.territoryLimitReached(maxAllowed)
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // 重叠检测：检查新领地是否与任何已有领地重叠（含自己的）
        if checkOverlapWithAllTerritories(path: coordinates) {
            debugLog("📤 [领地上传] ❌ 与已有领地重叠，拒绝上传")
            TerritoryLogger.shared.log(NSLocalizedString("error_territory_overlap", comment: ""), type: .error)
            throw TerritoryError.territoryOverlap
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
            "is_active": .bool(true),
            "distance_walked": .double(distanceWalked)
        ]

        debugLog("📤 [领地上传] 开始上传，点数: \(coordinates.count), 面积: \(String(format: "%.0f", area))m², 距离: \(String(format: "%.0f", distanceWalked))m")
        TerritoryLogger.shared.log("开始上传领地: \(coordinates.count)点, \(String(format: "%.0f", area))m²", type: .info)

        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase
                          .from("territories")
                          .insert(territoryData)
                          .execute()

                      debugLog("📤 [领地上传] ✅ 上传成功")
                      
                      // 🔥 修改重点 1：使用 String(format: NSLocalizedString(...)) 来支持动态翻译
                      // 这里 %.0f 是占位符，代表面积的数字
                      let successMessage = String(
                          format: NSLocalizedString("territory_upload_success_area_format", comment: ""),
                          area
                      )
                      
                      TerritoryLogger.shared.log(successMessage, type: .success)
                      
                  } catch {
                      debugLog("📤 [领地上传] ❌ 上传失败: \(error.localizedDescription)")
                      
                      // 🔥 修改重点 2：错误信息也要翻译
                      // 这里 %@ 是占位符，代表具体的错误原因
                      let errorMessage = String(
                          format: NSLocalizedString("error_territory_upload_failed_format", comment: ""),
                          error.localizedDescription
                      )
                      
                      TerritoryLogger.shared.log(errorMessage, type: .error)
                      throw TerritoryError.uploadFailed(error.localizedDescription)
              }
    }

    // MARK: - 累计距离

    /// 将本次行走距离累加到 player_profiles.total_distance_walked
    /// - Parameter distance: 本次行走距离（米）
    func addCumulativeDistance(_ distance: Double) async {
        guard distance > 0 else { return }
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            // 使用原子 RPC 避免 read-modify-write 竞态
            let params = IncrementDistanceParams(p_user_id: userId.uuidString, p_delta: distance)
            try await supabase.rpc(
                "increment_distance_walked",
                params: params
            ).execute()

            totalDistanceWalked += distance
            debugLog("📏 [距离累计] ✅ +\(String(format: "%.0f", distance))m → 总计 \(String(format: "%.0f", totalDistanceWalked))m")
        } catch {
            debugLog("📏 [距离累计] ❌ 更新失败: \(error.localizedDescription)")
        }
    }

    /// 从 player_profiles 加载累计行走总距离
    func loadTotalDistanceWalked() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            struct DistanceRow: Decodable { let totalDistanceWalked: Double?
                enum CodingKeys: String, CodingKey { case totalDistanceWalked = "total_distance_walked" }
            }
            let rows: [DistanceRow] = try await supabase
                .from("player_profiles")
                .select("total_distance_walked")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            totalDistanceWalked = rows.first?.totalDistanceWalked ?? 0
            debugLog("📏 [距离加载] 总计行走距离: \(String(format: "%.0f", totalDistanceWalked))m")
        } catch {
            debugLog("📏 [距离加载] ❌ 加载失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 拉取方法

    /// 加载所有有效领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        debugLog("📥 [领地加载] 开始加载所有领地...")

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
            debugLog("📥 [领地加载] ✅ 加载完成，共 \(response.count) 个领地")
            return response
        } catch {
            debugLog("📥 [领地加载] ❌ 加载失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    /// 加载当前用户的领地
    /// - Returns: 领地数组
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        debugLog("📥 [领地加载] 开始加载我的领地...")

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

            debugLog("📥 [领地加载] ✅ 加载完成，共 \(response.count) 个我的领地")

            // 同时加载累计行走距离
            await loadTotalDistanceWalked()

            return response
        } catch {
            debugLog("📥 [领地加载] ❌ 加载我的领地失败: \(error.localizedDescription)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - 删除方法

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        debugLog("🗑️ [领地删除] 开始删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            debugLog("🗑️ [领地删除] ✅ 删除成功")
            TerritoryLogger.shared.log(NSLocalizedString("territory_delete_success", comment: ""), type: .success)
            return true
        } catch {
            debugLog("🗑️ [领地删除] ❌ 删除失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log(String(format: NSLocalizedString("error_territory_delete_failed_format", comment: ""), error.localizedDescription), type: .error)
            return false
        }
    }
    
    // MARK: - 更新方法 (Phase 4)
    
    /// 更新领地名称
    /// - Parameters:
    ///   - territoryId: 领地 ID
    ///   - newName: 新名称
    /// - Returns: 是否成功
    func updateTerritoryName(territoryId: String, newName: String) async -> Bool {
        debugLog("✏️ [领地更新] 开始重命名领地: \(territoryId) -> \(newName)")

        guard !newName.isEmpty else {
            debugLog("✏️ [领地更新] ❌ 名称不能为空")
            return false
        }

        // 尝试 name 列（主列），失败后 fallback 到 custom_name
        do {
            try await supabase
                .from("territories")
                .update(["name": AnyJSON.string(newName)])
                .eq("id", value: territoryId)
                .execute()

            // 更新本地缓存
            if let index = territories.firstIndex(where: { $0.id == territoryId }) {
                var updatedTerritory = territories[index]
                updatedTerritory.customName = newName
                territories[index] = updatedTerritory
            }

            debugLog("✏️ [领地更新] ✅ 重命名成功 (name 列)")
            TerritoryLogger.shared.log(String(localized: "territory_rename_success"), type: .success)

            // 发送通知，让 TerritoryTabView 刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: territoryId)

            return true

        } catch {
            debugLog("✏️ [领地更新] ⚠️ name 列更新失败: \(error.localizedDescription)，尝试 custom_name 列...")
        }

        // Fallback: 尝试 custom_name 列
        do {
            try await supabase
                .from("territories")
                .update(["custom_name": AnyJSON.string(newName)])
                .eq("id", value: territoryId)
                .execute()

            if let index = territories.firstIndex(where: { $0.id == territoryId }) {
                var updatedTerritory = territories[index]
                updatedTerritory.customName = newName
                territories[index] = updatedTerritory
            }

            debugLog("✏️ [领地更新] ✅ 重命名成功 (custom_name 列)")
            TerritoryLogger.shared.log(String(localized: "territory_rename_success"), type: .success)
            NotificationCenter.default.post(name: .territoryUpdated, object: territoryId)

            return true

        } catch {
            debugLog("✏️ [领地更新] ❌ 重命名失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log(NSLocalizedString("error_start_point_in_others_territory", comment: ""), type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: NSLocalizedString("error_cannot_claim_in_others_territory", comment: ""),
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: 是否相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
        /// - Parameters:
        ///   - path: 路径坐标数组
        ///   - currentUserId: 当前用户ID
        /// - Returns: 碰撞检测结果
        func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
            guard path.count >= 2 else { return .safe }

            let otherTerritories = territories.filter { territory in
                // 确保不把自己算进去
                territory.userId.lowercased() != currentUserId.lowercased()
            }

            guard !otherTerritories.isEmpty else { return .safe }

            for i in 0..<(path.count - 1) {
                let pathStart = path[i]
                let pathEnd = path[i + 1]

                for territory in otherTerritories {
                    let polygon = territory.toCoordinates()
                    guard polygon.count >= 3 else { continue }

                    // 检查与领地每条边的相交
                    for j in 0..<polygon.count {
                        let boundaryStart = polygon[j]
                        let boundaryEnd = polygon[(j + 1) % polygon.count]

                        if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                            // 🔥 修复 1：日志也翻译一下（可选，但建议）
                            let logMsg = NSLocalizedString("error_path_crosses_others_territory", comment: "")
                            TerritoryLogger.shared.log(logMsg, type: .error)
                            
                            // 🔥🔥 修复 2：这是给用户看的警告，必须翻译！
                            return CollisionResult(
                                hasCollision: true,
                                collisionType: .pathCrossTerritory,
                                message: NSLocalizedString("error_trajectory_cannot_cross_others", comment: ""),
                                closestDistance: 0,
                                warningLevel: .violation
                            )
                        }
                    }

                    // 检查路径点是否在领地内
                    if isPointInPolygon(point: pathEnd, polygon: polygon) {
                        // 🔥 修复 3
                        let logMsg = NSLocalizedString("error_path_enters_others_territory", comment: "")
                        TerritoryLogger.shared.log(logMsg, type: .error)
                        
                        // 🔥🔥 修复 4
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pointInTerritory,
                            message: NSLocalizedString("error_trajectory_cannot_enter_others", comment: ""),
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }
            }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 最近距离（米）
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = String(format: NSLocalizedString("territory_warning_near_others_format", comment: ""), Int(minDistance))
        } else if minDistance > 25 {
            warningLevel = .warning
            message = String(format: NSLocalizedString("territory_warning_approaching_others_format", comment: ""), Int(minDistance))
        } else {
            warningLevel = .danger
            message = String(format: NSLocalizedString("territory_danger_entering_others_format", comment: ""), Int(minDistance))
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_distance_warning_format", comment: ""), warningLevel.description, Int(minDistance)), type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }

    // MARK: - 上传前重叠检测（含自身领地）

    /// 检查新路径是否与任何已有领地重叠（包括自己的领地）
    /// - Parameter path: 新领地的坐标数组
    /// - Returns: 是否存在重叠
    func checkOverlapWithAllTerritories(path: [CLLocationCoordinate2D]) -> Bool {
        guard path.count >= 3 else { return false }

        for territory in territories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            // (a) 新路径的任意边是否与已有领地的任意边相交
            for i in 0..<path.count {
                let pA = path[i]
                let pB = path[(i + 1) % path.count]

                for j in 0..<polygon.count {
                    let pC = polygon[j]
                    let pD = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pA, p2: pB, p3: pC, p4: pD) {
                        return true
                    }
                }
            }

            // (b) 新路径的任意点在已有领地内部
            for point in path {
                if isPointInPolygon(point: point, polygon: polygon) {
                    return true
                }
            }

            // (c) 已有领地的任意点在新领地内部（捕获完全包含的情况）
            for point in polygon {
                if isPointInPolygon(point: point, polygon: path) {
                    return true
                }
            }
        }

        return false
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)
    case loadFailed(String)
    case territoryLimitReached(Int)
    case territoryOverlap

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("error_not_logged_in", comment: "")
        case .invalidCoordinates:
            return NSLocalizedString("error_invalid_coordinates", comment: "")
        case .uploadFailed(let message):
            return String(format: NSLocalizedString("error_upload_failed_format", comment: ""), message)
        case .loadFailed(let message):
            return String(format: NSLocalizedString("error_load_failed_format", comment: ""), message)
        case .territoryLimitReached(let max):
            return String(format: NSLocalizedString("error_territory_limit_reached_format", comment: ""), max)
        case .territoryOverlap:
            return NSLocalizedString("error_territory_overlap", comment: "")
        }
    }
}

// MARK: - NotificationCenter Extension (Phase 4)

extension Notification.Name {
    /// 领地更新通知（用于刷新列表）
    static let territoryUpdated = Notification.Name("territoryUpdated")
}
