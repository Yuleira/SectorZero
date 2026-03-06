//
//  LocationManager.swift
//  EarthLord
//
//  Created by Claude on 02/01/2026.
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理授权状态变化
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Provider System (Day 35 Testing Support)
// Allows switching between Real GPS and Mock locations via Environment Variables
// Usage: Edit Scheme → Run → Arguments → Environment Variables
//        Add: MOCK_LOCATION = OSLO / TOKYO / PARIS / NEWYORK / SYDNEY / BEIJING / LONDON

#if DEBUG

/// Protocol for location providers (real GPS or mock)
protocol LocationProvider {
    var currentLocation: CLLocation? { get }
    var locationName: String { get }
}

/// Predefined mock locations for testing distance filtering
enum MockLocation: String, CaseIterable {
    case oslo = "OSLO"
    case tokyo = "TOKYO"
    case paris = "PARIS"
    case newyork = "NEWYORK"
    case sydney = "SYDNEY"
    case beijing = "BEIJING"
    case london = "LONDON"

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .oslo:     return CLLocationCoordinate2D(latitude: 59.91, longitude: 10.75)
        case .tokyo:    return CLLocationCoordinate2D(latitude: 35.67, longitude: 139.65)
        case .paris:    return CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35)
        case .newyork:  return CLLocationCoordinate2D(latitude: 40.71, longitude: -74.01)
        case .sydney:   return CLLocationCoordinate2D(latitude: -33.87, longitude: 151.21)
        case .beijing:  return CLLocationCoordinate2D(latitude: 39.90, longitude: 116.40)
        case .london:   return CLLocationCoordinate2D(latitude: 51.51, longitude: -0.13)
        }
    }

    var displayName: String {
        switch self {
        case .oslo:     return "Oslo, Norway"
        case .tokyo:    return "Tokyo, Japan"
        case .paris:    return "Paris, France"
        case .newyork:  return "New York, USA"
        case .sydney:   return "Sydney, Australia"
        case .beijing:  return "Beijing, China"
        case .london:   return "London, UK"
        }
    }
}

/// Real GPS location provider - wraps LocationManager's actual GPS
final class RealLocationProvider: LocationProvider {
    private weak var locationManager: LocationManager?

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    var currentLocation: CLLocation? {
        guard let coordinate = locationManager?.userLocation else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var locationName: String { "Real GPS" }
}

/// Mock location provider for testing - returns fixed coordinates
final class MockLocationProvider: LocationProvider {
    let mockLocation: MockLocation

    init(mockLocation: MockLocation) {
        self.mockLocation = mockLocation
        print("🧪 [MockLocationProvider] Initialized: \(mockLocation.displayName)")
        print("🧪 [MockLocationProvider] Coords: \(mockLocation.coordinate.latitude), \(mockLocation.coordinate.longitude)")
    }

    var currentLocation: CLLocation? {
        CLLocation(latitude: mockLocation.coordinate.latitude, longitude: mockLocation.coordinate.longitude)
    }

    var locationName: String { "Mock: \(mockLocation.rawValue)" }
}

/// Factory to create the appropriate location provider based on environment
enum LocationProviderFactory {
    static func createProvider(locationManager: LocationManager) -> LocationProvider {
        if let mockKey = ProcessInfo.processInfo.environment["MOCK_LOCATION"],
           let mock = MockLocation(rawValue: mockKey.uppercased()) {
            print("🧪 [LocationProviderFactory] MOCK_LOCATION=\(mockKey) detected")
            return MockLocationProvider(mockLocation: mock)
        }
        print("📍 [LocationProviderFactory] Using Real GPS provider")
        return RealLocationProvider(locationManager: locationManager)
    }

    static var isMockMode: Bool {
        ProcessInfo.processInfo.environment["MOCK_LOCATION"] != nil
    }
}

// MARK: - Territory Simulation Scenarios (DEBUG only)

/// 圈地模拟场景——覆盖验证的每个分支
enum TerritorySimScenario: String, CaseIterable, Identifiable {
    case validSquare  = "✅ 有效领地 (50×50m)"
    case tooFewPoints = "❌ 点数不足 (4点 < 最少6点)"
    case tooShort     = "❌ 距离不足 (< 30m)"
    case tooSmall     = "❌ 面积不足 (< 100m²)"

    var id: String { rawValue }

    /// 预制坐标。基准点：Oslo 59.91°N, 10.75°E
    /// 换算：1m ≈ 0.000009° lat，1m ≈ 0.000018° lon（cos59.91°≈0.5003）
    var coordinates: [CLLocationCoordinate2D] {
        switch self {

        case .validSquare:
            // 50×50m 方形，8 个点，面积 2500m²，周长 175m——全部通过验证
            return [
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75000), // SW 起点
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75045), // 25m 东
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75090), // SE 角（50m 东）
                CLLocationCoordinate2D(latitude: 59.91023, longitude: 10.75090), // 25m 北
                CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75090), // NE 角（50m 北）
                CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75045), // 25m 西
                CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75000), // NW 角（50m 西）
                CLLocationCoordinate2D(latitude: 59.91023, longitude: 10.75000), // 25m 南（距起点 25m）
            ]

        case .tooFewPoints:
            // 4 个点 → 点数检查失败（最少 6 点）
            return [
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75000),
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75090), // 50m 东
                CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75090), // 50m 北
                CLLocationCoordinate2D(latitude: 59.91045, longitude: 10.75000), // 50m 西
            ]

        case .tooShort:
            // 6 个点，但总距离仅约 5.5m → 距离检查失败（最少 30m）
            return [
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75000),
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75000), // 1.1m 北
                CLLocationCoordinate2D(latitude: 59.91002, longitude: 10.75000), // 1.1m 北
                CLLocationCoordinate2D(latitude: 59.91003, longitude: 10.75000), // 1.1m 北
                CLLocationCoordinate2D(latitude: 59.91002, longitude: 10.75000), // 1.1m 南
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75000), // 1.1m 南
            ]

        case .tooSmall:
            // 极细长条：宽 1.1m × 长 33m，面积 ~36m² → 面积检查失败（最少 100m²）
            // 总距离 ~68m（通过距离检查），6+ 点（通过点数检查）
            return [
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75000),
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75018), // 10m 东
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75036), // 20m 东
                CLLocationCoordinate2D(latitude: 59.91000, longitude: 10.75054), // 30m 东
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75054), // 1.1m 北
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75036), // 20m 西
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75018), // 10m 西
                CLLocationCoordinate2D(latitude: 59.91001, longitude: 10.75000), // 回到附近
            ]
        }
    }
}

#endif

// MARK: - Location Manager

/// GPS 定位管理器
/// 负责管理用户定位权限和实时位置更新
final class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - Location Provider (Day 35 Testing Support)

    #if DEBUG
    /// Location provider for abstracted location access (supports mock locations)
    private(set) lazy var provider: LocationProvider = LocationProviderFactory.createProvider(locationManager: self)

    /// Get current location via provider (respects MOCK_LOCATION environment variable)
    var providerLocation: CLLocation? {
        return provider.currentLocation
    }

    /// Check if using mock location
    var isUsingMockLocation: Bool {
        return LocationProviderFactory.isMockMode
    }

    /// Current location mode name (for debug UI)
    var locationModeName: String {
        return provider.locationName
    }
    #endif

    // MARK: - 发布属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation = false

    /// 是否仅有模糊定位（iOS 14+ accuracyAuthorization != .fullAccuracy）
    /// 圈地需要精确定位，为 true 时展示引导 alert
    @Published var needsPreciseLocation: Bool = false

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径
    @Published var isTracking = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（用于 Day16 圈地判断）
    @Published var isPathClosed = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed = false

    /// 当前速度（km/h）- 来自 GPS 硬件
    @Published var currentSpeed: Double = 0

    /// 累计行走距离（米）
    @Published var totalDistance: Double = 0

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（包含精度等完整信息，用于 Timer 采点）
    private(set) var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 最小采点距离（米）
    private let minDistanceForNewPoint: Double = 10.0

    /// 采点间隔（秒）
    private let pathUpdateInterval: TimeInterval = 2.0

    /// 闭环距离阈值（米）- 距离起点多近算闭环
    private let closureDistanceThreshold: Double = 50.0

    // MARK: - 验证常量

    /// 最少路径点数 - 至少需要多少点才检测闭环
    /// 6点 × 10m最小间距 = 60m最短周长
    private let minimumPathPoints: Int = 6

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 30.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度暂停阈值（km/h）
    private let speedStopThreshold: Double = 30.0

    /// 上次位置时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    /// 上次位置（用于计算速度）
    private var lastLocationForSpeed: CLLocation?

    /// 追踪开始时间（用于 GPS 稳定宽限期）
    private var trackingStartedAt: Date?

    /// 连续超速计数器 — 需要连续 3 次才停止，防止单次 GPS 噪声触发
    private var overspeedCount: Int = 0
    private let overspeedStopCount: Int = 3

    // MARK: - 计算属性

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝定位
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否尚未决定
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - 初始化

    private override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动 10 米才更新

        debugLog("📍 [定位管理器] 初始化完成，当前授权状态: \(authorizationStatusDescription)")
    }

    // MARK: - 公共方法

    /// 请求定位权限
    func requestPermission() {
        debugLog("📍 [定位管理器] 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 请求 Always 定位权限（后台圈地/探索需要）
    /// 必须先获得 WhenInUse 授权后才能调用
    func requestAlwaysPermission() {
        guard authorizationStatus == .authorizedWhenInUse else {
            debugLog("📍 [定位管理器] 需要先获得 WhenInUse 授权才能请求 Always")
            return
        }
        debugLog("📍 [定位管理器] 请求 Always 定位权限...")
        locationManager.requestAlwaysAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            debugLog("📍 [定位管理器] ⚠️ 未授权，无法开始定位")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        debugLog("📍 [定位管理器] 开始更新位置...")
        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        debugLog("📍 [定位管理器] 停止更新位置")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求位置更新（确保连续定位已启动）
    /// 不调用 CLLocationManager.requestLocation()，避免 kCLErrorDomain error 1（与
    /// startUpdatingLocation() 并发时的冲突）。改为依赖 didUpdateLocations 回调。
    func requestLocation() {
        guard isAuthorized else {
            debugLog("📍 [定位管理器] ⚠️ 未授权，无法请求位置")
            return
        }
        if !isUpdatingLocation {
            startUpdatingLocation()
        }
    }

    // MARK: - 后台定位控制

    /// 启用后台定位（供 ExplorationManager 等外部调用）
    func enableBackgroundTracking() {
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.activityType = .fitness
        debugLog("📍 [定位管理器] 后台定位已启用")
    }

    /// 关闭后台定位（省电）
    func disableBackgroundTracking() {
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.showsBackgroundLocationIndicator = false
        debugLog("📍 [定位管理器] 后台定位已关闭")
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            debugLog("📍 [路径追踪] ⚠️ 未授权，无法开始追踪")
            return
        }

        debugLog("📍 [路径追踪] 开始追踪...")
        TerritoryLogger.shared.log(NSLocalizedString("territory_start_claiming_tracking", comment: ""), type: .info)

        // 清除旧路径
        clearPath()

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastLocationForSpeed = nil

        // 重置累计距离
        totalDistance = 0

        // 标记开始追踪
        isTracking = true
        trackingStartedAt = Date()
        overspeedCount = 0

        // 启用后台定位（黑屏/锁屏时继续追踪）
        enableBackgroundTracking()

        // 如果只有 WhenInUse 权限，请求升级为 Always（更可靠的后台定位）
        if authorizationStatus == .authorizedWhenInUse {
            requestAlwaysPermission()
        }

        // 确保正在定位
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果有当前位置且精度足够，立即记录第一个点
        if let location = currentLocation,
           location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50 {
            let coordinate = location.coordinate
            pathCoordinates.append(coordinate)
            pathUpdateVersion += 1
            // 初始化速度检测的起始点
            lastLocationForSpeed = location
            lastLocationTimestamp = Date()
            debugLog("📍 [路径追踪] 记录起始点: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 精度: \(String(format: "%.0f", location.horizontalAccuracy))m")
        } else if let location = currentLocation {
            debugLog("📍 [路径追踪] ⚠️ 起始点 GPS 精度不足（\(String(format: "%.0f", location.horizontalAccuracy))m），等待更好信号")
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        // 使用 .common 模式确保后台/锁屏时定时器仍然触发
        let timer = Timer(timeInterval: pathUpdateInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
        RunLoop.main.add(timer, forMode: .common)
        pathUpdateTimer = timer
    }

    /// 停止路径追踪
    func stopPathTracking() {
        debugLog("📍 [路径追踪] 停止追踪，共记录 \(pathCoordinates.count) 个点")
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_stop_tracking_points_format", comment: ""), pathCoordinates.count), type: .info)

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 关闭后台定位（省电）
        disableBackgroundTracking()

        // 标记停止追踪
        isTracking = false

        // 重置所有状态（防止重复上传）
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastLocationForSpeed = nil
        trackingStartedAt = nil
        overspeedCount = 0

        // 重置累计距离
        totalDistance = 0

        // Clear persisted path — walk is complete
        clearSavedPath()
    }

    /// 恢复被中断的行走（含已保存路径）
    /// 设置 isTracking、重启采点定时器并启用后台定位。
    func resumePathTracking(with savedPath: [CLLocationCoordinate2D]) {
        guard !savedPath.isEmpty, isAuthorized else { return }

        pathCoordinates = savedPath
        pathUpdateVersion += 1
        isTracking = true
        trackingStartedAt = Date()   // fresh grace period for resumed walk
        overspeedCount = 0

        enableBackgroundTracking()
        if !isUpdatingLocation { startUpdatingLocation() }

        pathUpdateTimer?.invalidate()
        let timer = Timer(timeInterval: pathUpdateInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
        RunLoop.main.add(timer, forMode: .common)
        pathUpdateTimer = timer

        debugLog("📍 [路径追踪] ✅ 已恢复路径，共 \(savedPath.count) 个点")
        TerritoryLogger.shared.log("已恢复路径，共 \(savedPath.count) 个点", type: .info)
    }

    /// 清除路径
    func clearPath() {
        debugLog("📍 [路径追踪] 清除路径")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    /// 定时器回调：判断是否记录新点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard !isPathClosed else { return }  // 已闭环则不再记录
        guard let location = currentLocation else {
            debugLog("📍 [路径追踪] ⚠️ 当前位置为空，跳过采点")
            return
        }

        // 过滤低精度 GPS 数据（真机常见问题：室内/遮挡环境下精度差）
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 50 {
            debugLog("📍 [路径追踪] ⚠️ GPS 精度不足（\(String(format: "%.0f", location.horizontalAccuracy))m），跳过采点")
            return
        }

        let coordinate = location.coordinate

        // 如果是第一个点，直接记录
        if pathCoordinates.isEmpty {
            pathCoordinates.append(coordinate)
            pathUpdateVersion += 1
            savePathToDisk()
            lastLocationForSpeed = location
            lastLocationTimestamp = Date()
            debugLog("📍 [路径追踪] 记录第一个点: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
            TerritoryLogger.shared.log(NSLocalizedString("territory_record_first_point", comment: ""), type: .info)
            return
        }

        // 1. 先检查距离是否 ≥ 10 米
        guard let lastCoordinate = pathCoordinates.last else { return }
        let lastRecordedLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastRecordedLocation)

        // 距离不够，直接返回（不更新时间戳）
        guard distance >= minDistanceForNewPoint else {
            return
        }

        // 2. 距离够了，再检测速度
        if !validateMovementSpeed(newLocation: location) {
            // 严重超速（> 30 km/h），停止追踪
            return
        }

        // 3. 速度正常（或只是警告），记录新点
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1
        savePathToDisk()
        debugLog("📍 [路径追踪] 记录新点 #\(pathCoordinates.count): 距离上点 \(String(format: "%.1f", distance))m")
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_record_point_format", comment: ""), pathCoordinates.count, distance), type: .info)

        // 4. 记录后，更新速度检测的参考点
        lastLocationForSpeed = location
        lastLocationTimestamp = Date()

        // 5. 检测闭环
        checkPathClosure()
    }

    // MARK: - 闭环检测

    /// 检查路径是否闭环
    private func checkPathClosure() {
        // 已闭环则不再检测
        guard !isPathClosed else { return }

        // 点数不足，不检测
        guard pathCoordinates.count >= minimumPathPoints else {
            debugLog("📍 [闭环检测] 点数不足（\(pathCoordinates.count)/\(minimumPathPoints)），跳过检测")
            return
        }

        // 获取起点和当前点
        guard let startCoordinate = pathCoordinates.first,
              let currentCoordinate = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let currentLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        debugLog("📍 [闭环检测] 距起点 \(String(format: "%.1f", distanceToStart))m（阈值 \(closureDistanceThreshold)m）")
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_distance_from_start_format", comment: ""), distanceToStart), type: .info)

        // 判断是否闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新
            debugLog("📍 [闭环检测] ✅ 闭环成功！共 \(pathCoordinates.count) 个点")
            TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_loop_closed_format", comment: ""), distanceToStart), type: .success)

            // 停止追踪（但保留路径数据供验证和上传使用）
            pathUpdateTimer?.invalidate()
            pathUpdateTimer = nil
            isTracking = false

            // 关闭后台定位（省电）
            disableBackgroundTracking()

            // 重置速度检测状态
            speedWarning = nil
            isOverSpeed = false
            lastLocationTimestamp = nil
            lastLocationForSpeed = nil

            // 闭环后自动进行领地验证（此时数据还在）
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage

            // 注意：不清空 pathCoordinates，保留数据供确认登记时上传
            // 数据将在用户确认登记后由 stopPathTracking() 清空
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(latitude: pathCoordinates[i].latitude,
                                     longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                  longitude: pathCoordinates[i + 1].longitude)
            totalDistance += next.distance(from: current)
        }

        return totalDistance
    }

    /// 计算多边形面积（鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 地球半径（米）
        let earthRadius: Double = 6371000

        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        // 取绝对值并计算最终面积
        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测

    /// 判断两线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段起点
    ///   - p2: 第一条线段终点
    ///   - p3: 第二条线段起点
    ///   - p4: 第二条线段终点
    /// - Returns: true = 相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                    p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW（Counter-Clockwise）辅助函数
        /// 判断三点是否逆时针排列
        /// - Parameters:
        ///   - A: 第一个点
        ///   - B: 第二个点
        ///   - C: 第三个点
        /// - Returns: true = 逆时针
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                              (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径是否存在自相交
    /// - Returns: true = 有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_self_intersection_found_format", comment: ""), i, i+1, j, j+1), type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log(NSLocalizedString("territory_no_self_intersection", comment: ""), type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = String(format: NSLocalizedString("error_insufficient_points_format", comment: ""), pointCount, minimumPathPoints)
            TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_point_check_failed_format", comment: ""), pointCount), type: .error)
            TerritoryLogger.shared.log(String(format: NSLocalizedString("error_territory_validation_failed_format", comment: ""), error), type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_point_check_passed_format", comment: ""), pointCount), type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = String(format: NSLocalizedString("error_insufficient_distance_format", comment: ""), totalDistance, Int(minimumTotalDistance))
            TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_distance_check_failed_format", comment: ""), totalDistance), type: .error)
            TerritoryLogger.shared.log(String(format: NSLocalizedString("error_territory_validation_failed_format", comment: ""), error), type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_distance_check_passed_format", comment: ""), totalDistance), type: .info)

        // 3. Self-intersection check removed — real GPS tracks almost always
        //    self-intersect due to GPS drift. Points, distance, and area checks suffice.

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        if area < minimumEnclosedArea {
            let error = String(format: NSLocalizedString("error_insufficient_area_format", comment: ""), area, Int(minimumEnclosedArea))
            TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_area_check_failed_format", comment: ""), area), type: .error)
            TerritoryLogger.shared.log(String(format: NSLocalizedString("error_territory_validation_failed_format", comment: ""), error), type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_area_check_passed_format", comment: ""), area), type: .info)

        // 验证通过
        TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_validation_passed_format", comment: ""), area), type: .success)
        return (true, nil)
    }

    // MARK: - 速度检测

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        var speedKMH: Double = 0

        // 优先使用 GPS 硬件提供的速度（更准确）
        if newLocation.speed >= 0 {
            speedKMH = newLocation.speed * 3.6  // m/s 转 km/h
            debugLog("📍 [速度检测] GPS 速度: \(String(format: "%.1f", speedKMH)) km/h")
        } else {
            // GPS 速度无效时，回退到位置差计算
            guard let lastLocation = lastLocationForSpeed,
                  let lastTimestamp = lastLocationTimestamp else {
                return true  // 首次采点，无法计算速度
            }

            let distance = newLocation.distance(from: lastLocation)
            let timeDelta = Date().timeIntervalSince(lastTimestamp)

            guard timeDelta > 0 else { return true }

            speedKMH = (distance / timeDelta) * 3.6
            debugLog("📍 [速度检测] 计算速度: \(String(format: "%.1f", speedKMH)) km/h")
        }

        // 超过暂停阈值（30 km/h）
        if speedKMH > speedStopThreshold {
            // Give GPS 10 s to stabilize — skip auto-stop during grace period
            if let startedAt = trackingStartedAt, Date().timeIntervalSince(startedAt) < 10 {
                debugLog("📍 [速度检测] ⏳ 宽限期内忽略超速 (\(String(format: "%.1f", speedKMH)) km/h)")
                return true
            }
            // checkRealtimeSpeed already handles the consecutive stop logic;
            // here we just block recording the new point without stopping tracking.
            debugLog("📍 [速度检测] ⚠️ 采点速度过快 \(String(format: "%.1f", speedKMH)) km/h，跳过记录")
            return false
        }

        // 达到警告阈值（15-30 km/h）但未超过暂停阈值
        if speedKMH >= speedWarningThreshold {
            speedWarning = String(format: NSLocalizedString("map_moving_too_fast_format", comment: ""), speedKMH)
            isOverSpeed = true
            debugLog("📍 [速度检测] ⚠️ 速度较快，显示警告但继续记录")
            TerritoryLogger.shared.log(String(format: NSLocalizedString("map_speed_fast_continuing_format", comment: ""), speedKMH), type: .warning)
            return true  // 警告但继续记录
        }

        // 速度正常，清除警告
        if isOverSpeed {
            speedWarning = nil
            isOverSpeed = false
        }

        return true
    }

    /// 清除速度警告
    func clearSpeedWarning() {
        speedWarning = nil
        isOverSpeed = false
    }

    // MARK: - Path Persistence

    private let kSavedPath = "lm_saved_path_v1"
    private let kSavedPathDate = "lm_saved_path_date_v1"

    /// Persist pathCoordinates to UserDefaults after every append.
    private func savePathToDisk() {
        let raw = pathCoordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
        guard let data = try? JSONSerialization.data(withJSONObject: raw) else { return }
        UserDefaults.standard.set(data, forKey: kSavedPath)
        UserDefaults.standard.set(Date(), forKey: kSavedPathDate)
    }

    /// Returns the saved path if it is less than 24 hours old, nil otherwise.
    func loadSavedPath() -> [CLLocationCoordinate2D]? {
        guard
            let data = UserDefaults.standard.data(forKey: kSavedPath),
            let savedDate = UserDefaults.standard.object(forKey: kSavedPathDate) as? Date,
            Date().timeIntervalSince(savedDate) < 86400,
            let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]]
        else { return nil }
        return raw.compactMap {
            guard let lat = $0["lat"], let lon = $0["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Remove the persisted path from UserDefaults.
    func clearSavedPath() {
        UserDefaults.standard.removeObject(forKey: kSavedPath)
        UserDefaults.standard.removeObject(forKey: kSavedPathDate)
    }

    // MARK: - 圈地模拟 (DEBUG only)

#if DEBUG
    /// 注入预制坐标，触发完整的验证 + 上传流程，无需真实 GPS。
    /// MapTabView 的 onReceive($isPathClosed) 会自动响应并执行上传。
    func simulateClosedTerritory(_ scenario: TerritorySimScenario) {
        // 1. 重置所有追踪状态
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil
        isTracking = false
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 2. 注入坐标
        pathCoordinates = scenario.coordinates
        pathUpdateVersion += 1

        // 3. 计算总距离（等同于 calculateTotalPathDistance()）
        var dist: Double = 0
        for i in 1..<pathCoordinates.count {
            let a = CLLocation(latitude: pathCoordinates[i-1].latitude, longitude: pathCoordinates[i-1].longitude)
            let b = CLLocation(latitude: pathCoordinates[i].latitude, longitude: pathCoordinates[i].longitude)
            dist += b.distance(from: a)
        }
        totalDistance = dist

        // 4. 验证（设置 territoryValidationPassed / calculatedArea / territoryValidationError）
        let result = validateTerritory()
        territoryValidationPassed = result.isValid
        territoryValidationError = result.errorMessage

        debugLog("🧪 [模拟圈地] 场景: \(scenario.rawValue)")
        debugLog("🧪 [模拟圈地] 点数: \(pathCoordinates.count), 距离: \(String(format: "%.1f", dist))m, 面积: \(String(format: "%.1f", calculatedArea))m²")
        debugLog("🧪 [模拟圈地] 验证结果: \(territoryValidationPassed ? "✅ 通过" : "❌ 失败 — \(territoryValidationError ?? "")")")

        // 5. 触发闭环（主线程下一 RunLoop，确保 false→true 变更被 Combine 分两次发布）
        DispatchQueue.main.async { [weak self] in
            self?.isPathClosed = true
            self?.pathUpdateVersion += 1
        }
    }
#endif

    // MARK: - 私有方法

    /// 授权状态描述
    private var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return String(localized: "location_auth_not_determined")
        case .restricted:
            return String(localized: "location_auth_restricted")
        case .denied:
            return String(localized: "location_auth_denied")
        case .authorizedAlways:
            return String(localized: "location_auth_always")
        case .authorizedWhenInUse:
            return String(localized: "location_auth_when_in_use")
        @unknown default:
            return String(localized: "location_auth_unknown")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        let newStatus = manager.authorizationStatus

        // Ignore spurious 4→0 flips during permission upgrade (known iOS behavior)
        if newStatus == .notDetermined &&
           (oldStatus == .authorizedAlways || oldStatus == .authorizedWhenInUse) {
            debugLog("📍 [定位管理器] ⚠️ 忽略虚假授权翻转: \(oldStatus.rawValue) → 0")
            return
        }

        authorizationStatus = newStatus

        debugLog("📍 [定位管理器] 授权状态变化: \(oldStatus.rawValue) -> \(authorizationStatus.rawValue) (\(authorizationStatusDescription))")

        // 检查精确定位授权（iOS 14+）
        // 模糊定位会导致圈地 GPS 精度不足
        if #available(iOS 14.0, *) {
            needsPreciseLocation = manager.accuracyAuthorization != .fullAccuracy
            if needsPreciseLocation {
                debugLog("📍 [定位管理器] ⚠️ 仅有模糊定位权限，圈地功能受限")
            }
        }

        // 如果刚刚授权，自动开始定位
        if isAuthorized && !isUpdatingLocation {
            startUpdatingLocation()
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 过滤无效定位数据
        guard location.horizontalAccuracy >= 0 else {
            debugLog("📍 [定位管理器] ⚠️ 无效定位数据，跳过")
            return
        }

        let coordinate = location.coordinate
        userLocation = coordinate
        locationError = nil

        // 更新当前速度（来自 GPS 硬件，单位 m/s）
        // speed < 0 表示速度无效
        if location.speed >= 0 {
            currentSpeed = location.speed * 3.6  // 转换为 km/h
        }

        // 计算累计距离（如果正在追踪）
        if isTracking, let previousLocation = currentLocation {
            let distance = location.distance(from: previousLocation)
            // 只累计有效距离（过滤 GPS 漂移）
            if distance >= 1.0 && distance <= 100.0 {
                totalDistance += distance
            }
        }

        // 保存当前位置（Timer 采点需要用）
        currentLocation = location

        // 实时速度检测（追踪模式下）
        if isTracking {
            checkRealtimeSpeed(location: location)
        }

        debugLog("📍 [定位管理器] 位置更新: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 速度: \(String(format: "%.1f", currentSpeed)) km/h")

        // 追踪时或调试模式下记录位置更新日志
        if isTracking || TerritoryLogger.shared.isDebugMode {
            TerritoryLogger.shared.log("GPS: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 速度: \(String(format: "%.1f", currentSpeed)) km/h", type: .info)
        }
    }

    /// 实时速度检测
    /// - Parameter location: 当前位置
    private func checkRealtimeSpeed(location: CLLocation) {
        // 优先使用 GPS 硬件速度
        var speedKMH: Double = 0

        if location.speed >= 0 {
            speedKMH = location.speed * 3.6
        } else if let lastLocation = lastLocationForSpeed,
                  let lastTimestamp = lastLocationTimestamp {
            // GPS 速度无效时，回退到位置差计算
            let distance = location.distance(from: lastLocation)
            let timeDelta = Date().timeIntervalSince(lastTimestamp)
            if timeDelta > 0 {
                speedKMH = (distance / timeDelta) * 3.6
            }
        }

        // 超过暂停阈值（30 km/h）
        if speedKMH > speedStopThreshold {
            // Give GPS 10 s to stabilize — skip auto-stop during grace period
            if let startedAt = trackingStartedAt, Date().timeIntervalSince(startedAt) < 10 {
                debugLog("📍 [速度检测] ⏳ 宽限期内忽略超速 (\(String(format: "%.1f", speedKMH)) km/h)")
                return
            }
            // Require 3 consecutive readings before stopping — prevents single GPS spike
            overspeedCount += 1
            debugLog("📍 [速度检测] ⚠️ 超速 \(String(format: "%.1f", speedKMH)) km/h (\(overspeedCount)/\(overspeedStopCount)次)")
            speedWarning = String(format: NSLocalizedString("map_speed_too_fast_tracking_paused_format", comment: ""), speedKMH)
            isOverSpeed = true
            if overspeedCount >= overspeedStopCount {
                debugLog("📍 [速度检测] ❌ 持续超速，自动停止追踪")
                TerritoryLogger.shared.log(String(format: NSLocalizedString("territory_overspeed_stopped_format", comment: ""), speedKMH), type: .error)
                stopPathTracking()
            }
            return
        }

        // 速度正常 — 重置超速计数
        overspeedCount = 0

        // 达到警告阈值（15-30 km/h）
        if speedKMH >= speedWarningThreshold {
            speedWarning = String(format: NSLocalizedString("map_moving_too_fast_format", comment: ""), speedKMH)
            isOverSpeed = true
        } else if isOverSpeed {
            // 速度恢复正常，清除警告
            speedWarning = nil
            isOverSpeed = false
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugLog("📍 [定位管理器] ❌ 定位失败: \(error.localizedDescription)")

        // 处理不同的错误类型
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = NSLocalizedString("error_location_permission_denied", comment: "")
            case .locationUnknown:
                // 暂时性 GPS 失锁，在连续定位（追踪）期间属于正常噪声，不上报 UI
                if isTracking {
                    debugLog("📍 [定位管理器] ℹ️ locationUnknown (暂时性，追踪中忽略)")
                } else {
                    locationError = NSLocalizedString("error_cannot_get_location", comment: "")
                }
            case .network:
                locationError = NSLocalizedString("error_network_error", comment: "")
            default:
                locationError = String(format: NSLocalizedString("error_location_failed_format", comment: ""), error.localizedDescription)
            }
        } else {
            locationError = String(format: NSLocalizedString("error_location_failed_format", comment: ""), error.localizedDescription)
        }
    }
}
