//
//  PlayerPresenceManager.swift
//  EarthLord
//
//  玩家在线状态管理器
//  负责位置上报、附近玩家密度查询
//

import Foundation
import CoreLocation
import Combine
import Supabase
import UIKit

/// 玩家在线状态管理器
/// 负责：
/// - 定期上报位置到服务器
/// - 查询附近玩家数量
/// - 管理在线/离线状态
@MainActor
final class PlayerPresenceManager: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerPresenceManager()

    // MARK: - 发布属性

    /// 附近玩家数量（不含自己）
    @Published private(set) var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published private(set) var densityLevel: DensityLevel = .alone

    /// 是否正在上报位置
    @Published private(set) var isReporting: Bool = false

    /// 上次成功上报时间
    @Published private(set) var lastReportTime: Date?

    // MARK: - 配置常量

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30.0

    /// 触发上报的最小移动距离（米）
    private let minDistanceForReport: Double = 50.0

    /// 附近玩家查询半径（米）
    private let nearbyRadius: Int = 1000

    /// 在线判断超时（分钟）
    private let onlineTimeoutMinutes: Int = 5

    // MARK: - 私有属性

    private let locationManager = LocationManager.shared
    private var reportTimer: Timer?
    private var lastReportedLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var isTracking: Bool = false

    /// 前后台状态观察者
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - 初始化

    private init() {
        print("📍 [玩家在线] 管理器初始化")
        setupNotificationObservers()
    }

    deinit {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - 公共方法

    /// 开始位置追踪
    /// - Note: 应在用户登录后调用
    func startPresenceTracking() {
        guard !isTracking else {
            print("📍 [玩家在线] 已在追踪中，跳过")
            return
        }

        guard AuthManager.shared.isAuthenticated else {
            print("📍 [玩家在线] 用户未登录，无法开始追踪")
            return
        }

        print("📍 [玩家在线] 开始位置追踪")
        isTracking = true

        // 立即上报一次位置
        Task {
            await reportCurrentLocation()
        }

        // 启动定时上报
        startReportTimer()

        // 监听位置变化
        setupLocationObserver()
    }

    /// 停止位置追踪
    func stopPresenceTracking() {
        guard isTracking else { return }

        print("📍 [玩家在线] 停止位置追踪")
        isTracking = false

        // 停止定时器
        reportTimer?.invalidate()
        reportTimer = nil

        // 清除订阅
        cancellables.removeAll()

        // 标记离线
        Task {
            await markOffline()
        }
    }

    /// 手动触发位置上报
    /// - Note: 用于探索开始时立即上报
    func reportCurrentLocation() async {
        guard AuthManager.shared.isAuthenticated else {
            print("📍 [玩家在线] 用户未登录，跳过上报")
            return
        }

        guard let coordinate = locationManager.userLocation else {
            print("📍 [玩家在线] 无法获取用户位置，跳过上报")
            return
        }

        await reportLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// 查询附近玩家数量并返回密度等级
    /// - Returns: 密度等级
    @discardableResult
    func fetchNearbyPlayerCount() async -> DensityLevel {
        guard AuthManager.shared.isAuthenticated else {
            print("📍 [玩家在线] 用户未登录，返回默认密度")
            return .alone
        }

        guard let coordinate = locationManager.userLocation else {
            print("📍 [玩家在线] 无法获取用户位置，返回默认密度")
            return .alone
        }

        do {
            // 使用 AnyJSON 构建 RPC 参数
            let params: [String: AnyJSON] = [
                "p_latitude": .double(coordinate.latitude),
                "p_longitude": .double(coordinate.longitude),
                "p_radius_meters": .integer(nearbyRadius),
                "p_timeout_minutes": .integer(onlineTimeoutMinutes)
            ]

            let count: Int = try await supabase.rpc(
                "nearby_players_count",
                params: params
            ).execute().value

            nearbyPlayerCount = count
            densityLevel = DensityLevel.from(playerCount: count)

            print("📍 [玩家在线] 附近玩家: \(count) 人，密度等级: \(densityLevel)")

            return densityLevel
        } catch {
            print("📍 [玩家在线] 查询附近玩家失败: \(error.localizedDescription)")
            // 查询失败时返回默认值
            return .alone
        }
    }

    // MARK: - 私有方法

    /// 设置通知观察者
    private func setupNotificationObservers() {
        // 进入后台
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEnterBackground()
            }
        }

        // 回到前台
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEnterForeground()
            }
        }
    }

    /// 处理进入后台
    private func handleEnterBackground() {
        guard isTracking else { return }
        print("📍 [玩家在线] App 进入后台，标记离线")

        // 停止定时器
        reportTimer?.invalidate()
        reportTimer = nil

        // 标记离线
        Task {
            await markOffline()
        }
    }

    /// 处理回到前台
    private func handleEnterForeground() {
        guard isTracking else { return }
        print("📍 [玩家在线] App 回到前台，恢复追踪")

        // 立即上报位置
        Task {
            await reportCurrentLocation()
        }

        // 重新启动定时器
        startReportTimer()
    }

    /// 启动定时上报
    private func startReportTimer() {
        reportTimer?.invalidate()

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.reportCurrentLocation()
            }
        }

        print("📍 [玩家在线] 定时上报已启动（间隔: \(Int(reportInterval))秒）")
    }

    /// 设置位置变化监听
    private func setupLocationObserver() {
        // 监听位置变化，移动超过50米时立即上报
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    self?.checkDistanceAndReport(coordinate: coordinate)
                }
            }
            .store(in: &cancellables)
    }

    /// 检查移动距离，超过阈值时上报
    private func checkDistanceAndReport(coordinate: CLLocationCoordinate2D) {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let lastLocation = lastReportedLocation else {
            return
        }

        let distance = currentLocation.distance(from: lastLocation)

        if distance >= minDistanceForReport {
            print("📍 [玩家在线] 移动超过 \(Int(minDistanceForReport))m，触发上报")
            Task {
                await reportLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
    }

    /// 上报位置到服务器
    private func reportLocation(latitude: Double, longitude: Double) async {
        guard !isReporting else {
            print("📍 [玩家在线] 正在上报中，跳过")
            return
        }

        isReporting = true

        do {
            // 使用 AnyJSON 构建 RPC 参数
            let params: [String: AnyJSON] = [
                "p_latitude": .double(latitude),
                "p_longitude": .double(longitude),
                "p_is_online": .bool(true)
            ]

            // 调用 Supabase RPC 函数（Upsert）
            try await supabase.rpc(
                "upsert_player_location",
                params: params
            ).execute()

            // 更新本地状态
            lastReportedLocation = CLLocation(latitude: latitude, longitude: longitude)
            lastReportTime = Date()

            print("📍 [玩家在线] ✅ 位置上报成功 (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))")
        } catch {
            print("📍 [玩家在线] ❌ 位置上报失败: \(error.localizedDescription)")
        }

        isReporting = false
    }

    /// 标记玩家离线
    private func markOffline() async {
        do {
            try await supabase.rpc("mark_player_offline").execute()
            print("📍 [玩家在线] ✅ 已标记为离线")
        } catch {
            print("📍 [玩家在线] ❌ 标记离线失败: \(error.localizedDescription)")
        }
    }
}
