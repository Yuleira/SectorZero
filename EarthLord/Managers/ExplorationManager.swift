//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索流程、GPS追踪、距离计算、POI搜刮
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 探索轨迹点
struct ExplorationTrackPoint {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let accuracy: Double
}

/// 搜刮结果
struct ScavengeResult {
    let poi: NearbyPOI
    let items: [CollectedItem]
    let storageWarning: Bool
}

/// 探索管理器
/// 负责管理探索流程、GPS追踪、距离计算、POI搜刮
@MainActor
final class ExplorationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - 发布属性

    /// 当前探索状态
    @Published private(set) var state: ExplorationState = .idle

    /// 是否正在探索
    @Published private(set) var isExploring = false

    /// 当前探索的有效距离（米）
    @Published private(set) var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published private(set) var currentDuration: TimeInterval = 0

    /// 探索轨迹点
    @Published private(set) var trackPoints: [ExplorationTrackPoint] = []

    /// 最新探索结果
    @Published var latestResult: ExplorationResult?

    /// 当前速度（米/秒）
    @Published private(set) var currentSpeed: Double = 0

    /// 速度警告消息
    @Published private(set) var speedWarning: String?

    // MARK: - POI 相关属性

    /// 附近POI列表
    @Published private(set) var nearbyPOIs: [NearbyPOI] = []

    /// 是否显示POI弹窗
    @Published var showPOIPopup = false

    /// 当前接近的POI
    @Published var currentPOI: NearbyPOI?

    /// 是否正在搜索POI
    @Published private(set) var isSearchingPOIs = false

    /// 最新搜刮结果
    @Published var latestScavengeResult: ScavengeResult?

    /// 是否显示搜刮结果
    @Published var showScavengeResult = false

    /// 能量不足提示（触发 Store 导航）
    @Published var showEnergyDepletedAlert = false

    // MARK: - 私有属性

    private let locationManager = LocationManager.shared
    private var startTime: Date?
    private var durationTimer: Timer?
    private var samplingTimer: Timer?
    private var lastValidLocation: CLLocation?
    private var lastLocationTimestamp: Date?
    private var cancellables = Set<AnyCancellable>()

    /// 超速警告开始时间
    private var speedWarningStartTime: Date?

    /// 速度检测定时器
    private var speedCheckTimer: Timer?

    // MARK: - POI 私有属性

    /// 地理围栏管理器
    private let geofenceManager = CLLocationManager()

    /// POI接近检测定时器
    private var poiProximityTimer: Timer?

    /// POI触发范围（米）
    /// 注意：设置为100米以便测试，生产环境可以调整为更小的值
    private let poiTriggerRadius: CLLocationDistance = 100

    /// 当前密度等级（决定POI显示数量）
    private var currentDensityLevel: DensityLevel = .alone

    // MARK: - 配置常量

    /// 最小精度要求（米）
    private let minAccuracy: Double = 50.0
    /// 最大跳变距离（米）
    private let maxJumpDistance: Double = 100.0
    /// 最小时间间隔（秒）
    private let minTimeInterval: TimeInterval = 1.0
    /// 采点间隔（秒）
    private let sampleInterval: TimeInterval = 3.0
    /// 最大允许速度（米/秒）- 30km/h = 8.33m/s
    private let maxAllowedSpeed: Double = 8.33
    /// 超速容忍时间（秒）
    private let speedWarningTimeout: TimeInterval = 10.0

    // MARK: - 初始化

    private override init() {
        super.init()
        debugLog("🔍 [探索管理器] 初始化完成")
        debugLog("🔍 [探索管理器] 配置：最大速度=\(String(format: "%.1f", maxAllowedSpeed))m/s (\(String(format: "%.0f", maxAllowedSpeed * 3.6))km/h)")
    }

    // MARK: - 公共方法

    /// 开始探索
    func startExploration() {
            guard canStartExploration() else {
                debugLog("🔍 [探索] ❌ 无法开始探索")
                return
            }

            debugLog("🔍 [探索] ✅ 开始探索")
            
        // 重置状态
        resetExplorationData()

        // 设置状态
        state = .exploring
        isExploring = true
        startTime = Date()

        // 确保定位服务运行，并启用后台定位
        locationManager.enableBackgroundTracking()
        if !locationManager.isUpdatingLocation {
            debugLog("🔍 [探索] 启动定位服务")
            locationManager.startUpdatingLocation()
        }

        // 启动时长计时器
        startDurationTimer()

        // 启动采点定时器
        startSamplingTimer()

        // 启动速度检测定时器
        startSpeedCheckTimer()

        // 上报位置并查询附近玩家密度，然后搜索POI
        Task {
            // 1. 上报当前位置
            await PlayerPresenceManager.shared.reportCurrentLocation()

            // 2. 查询附近玩家数量，确定密度等级
            currentDensityLevel = await PlayerPresenceManager.shared.fetchNearbyPlayerCount()
            debugLog("🔍 [探索] 当前密度等级: \(currentDensityLevel)，最多显示 \(currentDensityLevel.maxPOICount) 个POI")

            // 3. 根据密度搜索并设置POI
            await searchAndSetupPOIs()
        }

        debugLog("🔍 [探索] 所有定时器已启动")
    }

    /// 结束探索
    func stopExploration() async -> ExplorationResult? {
        guard isExploring else {
            debugLog("🔍 [探索] ⚠️ 当前未在探索状态，无法结束")
            return nil
        }

        debugLog("🔍 [探索] 🏁 结束探索，开始计算奖励...")

        state = .processing
        isExploring = false

        // 停止计时器
        stopTimers()

        // 清理POI和围栏
        cleanupPOIs()

        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0

        debugLog("🔍 [探索] 探索数据 - 距离: \(String(format: "%.1f", currentDistance))m，时长: \(Int(duration))秒，采点: \(trackPoints.count)个")

        // 计算奖励等级
        let tier = RewardTier.from(distance: currentDistance)
        debugLog("🔍 [探索] 奖励等级: \(LanguageManager.shared.translate(tier.localizedName))")

        // 生成奖励物品
        var collectedItems: [CollectedItem] = []
        if tier != .none {
            debugLog("🔍 [探索] 开始生成奖励物品...")
            collectedItems = await RewardGenerator.shared.generateRewards(tier: tier)
            debugLog("🔍 [探索] 生成了 \(collectedItems.count) 个物品")
        } else {
            debugLog("🔍 [探索] 未达到奖励门槛，不生成物品")
        }

        // 保存探索记录到数据库
        debugLog("🔍 [探索] 保存探索记录到数据库...")
        let sessionId = await saveExplorationSession(
            startTime: startTime ?? endTime,
            endTime: endTime,
            duration: Int(duration),
            distance: currentDistance,
            tier: tier,
            itemsCount: collectedItems.count
        )

        // 将物品保存到背包（重置/捕获存储满警告）
        // 即使探索记录保存失败(sessionId为nil)，也要保存物品到背包
        var hadStorageWarning = false
        if !collectedItems.isEmpty {
            debugLog("🔍 [探索] 将物品保存到背包...")
            InventoryManager.shared.storageFullWarning = false
            await InventoryManager.shared.addItems(
                collectedItems,
                sourceType: "exploration",
                sourceSessionId: sessionId
            )
            hadStorageWarning = InventoryManager.shared.storageFullWarning
            InventoryManager.shared.storageFullWarning = false
            debugLog("🔍 [探索] 物品已保存到背包")
        }

        if sessionId == nil {
            debugLog("🔍 [探索] ⚠️ 探索记录保存失败，但物品已保存到背包")
            TerritoryLogger.shared.log("探索记录保存失败，物品已保存", type: .warning)
        }

        // 保存累计行走距离到 Profile
        await TerritoryManager.shared.addCumulativeDistance(currentDistance)
        debugLog("🔍 [探索] 累计距离已保存: \(String(format: "%.1f", currentDistance))m")

        // 构建结果
        let stats = ExplorationStats(
            totalDistance: currentDistance,
            duration: duration,
            pointsVerified: trackPoints.count,
            distanceRank: LanguageManager.shared.translate(tier.localizedName)
        )

        let result = ExplorationResult(
            isSuccess: tier != .none,
            message: tier == .none ? NSLocalizedString("exploration_distance_insufficient", comment: "") : NSLocalizedString("exploration_success", comment: ""),
            itemsCollected: collectedItems,
            experienceGained: calculateExperience(tier: tier, distance: currentDistance),
            distanceWalked: currentDistance,
            stats: stats,
            startTime: startTime ?? endTime,
            endTime: endTime,
            storageWarning: hadStorageWarning
        )

        latestResult = result
        state = .completed

        debugLog("🔍 [探索] ✅ 探索完成 - 距离: \(String(format: "%.1f", currentDistance))m，等级: \(LanguageManager.shared.translate(tier.localizedName))，物品: \(collectedItems.count)个，经验: \(result.experienceGained)")

        return result
    }

    /// 取消探索（不保存记录）
    func cancelExploration() {
        guard isExploring else { return }

        debugLog("🔍 [探索] ❌ 取消探索（不保存记录）")

        stopTimers()
        resetExplorationData()
        state = .idle
        isExploring = false
    }

    /// 因超速停止探索
    func stopExplorationDueToSpeeding() async {
        guard isExploring else { return }

        debugLog("🔍 [探索] 🚫 因超速停止探索")

        state = .processing
        isExploring = false

        // 停止计时器
        stopTimers()

        // 设置失败结果
        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0

        let stats = ExplorationStats(
            totalDistance: currentDistance,
            duration: duration,
            pointsVerified: trackPoints.count,
            distanceRank: NSLocalizedString("exploration_failed", comment: "")
        )

        let result = ExplorationResult(
            isSuccess: false,
            message: NSLocalizedString("error_exploration_speed_exceeded", comment: ""),
            itemsCollected: [],
            experienceGained: 0,
            distanceWalked: currentDistance,
            stats: stats,
            startTime: startTime ?? endTime,
            endTime: endTime
        )

        latestResult = result
        state = .failed(NSLocalizedString("map_speed_too_fast", comment: ""))

        debugLog("🔍 [探索] ❌ 探索失败 - 原因：超速")

        // 清理数据
        resetExplorationData()
    }

    // MARK: - 私有方法

    /// 检查是否可以开始探索
    private func canStartExploration() -> Bool {
        guard state == .idle || state == .completed || isFailedState() else {
            debugLog("🔍 [探索] 当前状态不允许开始探索: \(state)")
            return false
        }

        guard locationManager.isAuthorized else {
            state = .failed(NSLocalizedString("error_location_permission_required", comment: ""))
            return false
        }

        return true
    }

    /// 检查是否为失败状态
    private func isFailedState() -> Bool {
        if case .failed = state {
            return true
        }
        return false
    }

    /// 重置探索数据
    private func resetExplorationData() {
        currentDistance = 0
        currentDuration = 0
        currentSpeed = 0
        trackPoints.removeAll()
        startTime = nil
        lastValidLocation = nil
        lastLocationTimestamp = nil
        latestResult = nil
        speedWarning = nil
        speedWarningStartTime = nil
        // 重置POI相关数据
        nearbyPOIs.removeAll()
        showPOIPopup = false
        currentPOI = nil
        latestScavengeResult = nil
        showScavengeResult = false
        debugLog("🔍 [探索] 探索数据已重置")
    }

    /// 启动时长计时器（使用 .common 模式确保锁屏时继续运行）
    private func startDurationTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.currentDuration = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        durationTimer = timer
    }

    /// 启动采点定时器（使用 .common 模式确保锁屏时继续运行）
    private func startSamplingTimer() {
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.sampleCurrentLocation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        samplingTimer = timer
    }

    /// 启动速度检测定时器（使用 .common 模式确保锁屏时继续运行）
    private func startSpeedCheckTimer() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkSpeed()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        speedCheckTimer = timer
    }

    /// 检测速度
    private func checkSpeed() {
        guard isExploring else { return }

        // 从 locationManager 获取当前完整位置
        guard let clLocation = locationManager.currentLocation else {
            return
        }

        // 使用两点间距离和时间差来计算速度
        if let lastLocation = lastValidLocation, let lastTime = lastLocationTimestamp {
            let timeInterval = Date().timeIntervalSince(lastTime)
            if timeInterval > 0 {
                let distance = clLocation.distance(from: lastLocation)
                let speed = distance / timeInterval  // 米/秒
                currentSpeed = speed

                let speedKmh = speed * 3.6  // 转换为 km/h

                debugLog("🔍 [速度检测] 当前速度: \(String(format: "%.1f", speedKmh))km/h (\(String(format: "%.2f", speed))m/s)")

                // 检查是否超速
                if speed > maxAllowedSpeed {
                    handleSpeeding(speed: speed)
                } else {
                    // 速度正常，清除警告
                    if speedWarning != nil {
                        debugLog("🔍 [速度检测] ✅ 速度已恢复正常")
                        speedWarning = nil
                        speedWarningStartTime = nil
                    }
                }
            }
        }
    }

    /// 处理超速
    private func handleSpeeding(speed: Double) {
        let speedKmh = speed * 3.6

        if speedWarningStartTime == nil {
            // 第一次超速，开始警告
            speedWarningStartTime = Date()
            speedWarning = String(format: NSLocalizedString("exploration_speed_warning_current", comment: ""), speedKmh)
            debugLog("🔍 [速度检测] ⚠️ 超速警告：当前速度 \(String(format: "%.1f", speedKmh))km/h，开始倒计时")
        } else {
            // 持续超速，检查是否超过容忍时间
            guard let startTime = speedWarningStartTime else { return }
            let warningDuration = Date().timeIntervalSince(startTime)

            if warningDuration >= speedWarningTimeout {
                // 超过10秒仍然超速，停止探索
                debugLog("🔍 [速度检测] 🚫 超速超过\(Int(speedWarningTimeout))秒，停止探索")
                Task { [weak self] in
                    await self?.stopExplorationDueToSpeeding()
                }
            } else {
                // 更新警告消息，显示剩余时间
                let remainingTime = Int(speedWarningTimeout - warningDuration)
                speedWarning = String(format: NSLocalizedString("exploration_speed_warning_countdown", comment: ""), speedKmh, remainingTime)
                debugLog("🔍 [速度检测] ⚠️ 持续超速 \(String(format: "%.1f", warningDuration))秒，剩余 \(remainingTime) 秒")
            }
        }
    }

    /// 停止计时器
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        samplingTimer?.invalidate()
        samplingTimer = nil
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
        // 关闭后台定位（省电）
        locationManager.disableBackgroundTracking()
        debugLog("🔍 [探索] 所有定时器已停止，后台定位已关闭")
    }

    /// 采集当前位置
    private func sampleCurrentLocation() {
        guard isExploring else {
            debugLog("🔍 [采点] ⚠️ 未在探索状态，跳过采点")
            return
        }

        // 使用完整的 CLLocation 对象（包含精度信息），避免用 CLLocation(latitude:longitude:) 创建导致精度为 -1
        guard let location = locationManager.currentLocation else {
            debugLog("🔍 [采点] ⚠️ 当前位置为空，跳过采点")
            return
        }

        let coordinate = location.coordinate
        let now = Date()

        debugLog("🔍 [采点] 尝试采集位置 - 坐标: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 精度: \(String(format: "%.1f", location.horizontalAccuracy))m")

        // 位置过滤
        if !validateLocation(location, timestamp: now) {
            debugLog("🔍 [采点] ❌ 位置验证失败，跳过")
            return
        }

        // 计算与上一个有效点的距离
        var distanceIncrement: Double = 0
        if let last = lastValidLocation {
            distanceIncrement = location.distance(from: last)
            debugLog("🔍 [采点] 距离增量: \(String(format: "%.2f", distanceIncrement))m")
        } else {
            debugLog("🔍 [采点] 这是第一个有效点")
        }

        // 记录轨迹点
        let trackPoint = ExplorationTrackPoint(
            coordinate: coordinate,
            timestamp: now,
            accuracy: location.horizontalAccuracy
        )
        trackPoints.append(trackPoint)

        // 累加距离
        currentDistance += distanceIncrement

        // 更新最后位置
        lastValidLocation = location
        lastLocationTimestamp = now

        debugLog("🔍 [采点] ✅ 采点成功 #\(trackPoints.count) - 增加: \(String(format: "%.1f", distanceIncrement))m，总距离: \(String(format: "%.1f", currentDistance))m")
    }

    /// 位置有效性验证
    private func validateLocation(_ location: CLLocation, timestamp: Date) -> Bool {
        // 1. 精度过滤（负值表示无效）
        if location.horizontalAccuracy > minAccuracy || location.horizontalAccuracy < 0 {
            debugLog("🔍 [探索] 精度不足: \(location.horizontalAccuracy)m，跳过")
            return false
        }

        // 2. 时间间隔过滤
        if let lastTime = lastLocationTimestamp {
            let interval = timestamp.timeIntervalSince(lastTime)
            if interval < minTimeInterval {
                debugLog("🔍 [探索] 时间间隔不足: \(interval)s，跳过")
                return false
            }
        }

        // 3. 跳变过滤
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)
            if distance > maxJumpDistance {
                debugLog("🔍 [探索] 位置跳变过大: \(distance)m，跳过")
                return false
            }
        }

        return true
    }

    /// 保存探索记录到数据库
    private func saveExplorationSession(
        startTime: Date,
        endTime: Date,
        duration: Int,
        distance: Double,
        tier: RewardTier,
        itemsCount: Int
    ) async -> UUID? {
        guard let userId = AuthManager.shared.currentUser?.id else {
            debugLog("🔍 [探索] 未登录，无法保存探索记录")
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessionData = InsertExplorationSession(
            userId: userId.uuidString,
            startedAt: formatter.string(from: startTime),
            endedAt: formatter.string(from: endTime),
            durationSeconds: duration,
            totalDistance: distance,
            pointCount: trackPoints.count,
            rewardTier: tier.rawValue,
            itemsCount: itemsCount
        )

        do {
            let response: [ExplorationSession] = try await supabase
                .from("exploration_sessions")
                .insert(sessionData)
                .select()
                .execute()
                .value

            debugLog("🔍 [探索] 探索记录保存成功")
            return response.first?.id
        } catch {
            debugLog("🔍 [探索] 保存探索记录失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 计算经验值
    private func calculateExperience(tier: RewardTier, distance: Double) -> Int {
        // 基础经验 = 距离 / 10
        let baseExp = Int(distance / 10)

        // 等级加成
        let tierMultiplier: Double
        switch tier {
        case .none: tierMultiplier = 0
        case .bronze: tierMultiplier = 1.0
        case .silver: tierMultiplier = 1.5
        case .gold: tierMultiplier = 2.0
        case .diamond: tierMultiplier = 3.0
        }

        return Int(Double(baseExp) * tierMultiplier)
    }

    // MARK: - POI 搜索与管理

    /// 手动触发POI搜索（用于测试）
    /// 无需开始探索即可搜索附近POI
    public func manualSearchPOIs() async {
        debugLog("🏪 [POI] 手动触发POI搜索...")
        await searchAndSetupPOIs()
    }

    /// 搜索并设置附近POI
    private func searchAndSetupPOIs() async {
        isSearchingPOIs = true
        debugLog("🏪 [POI] 开始搜索附近POI...")

        // 等待用户位置准备好（最多等待5秒）
        var userLocation = locationManager.userLocation
        var waitCount = 0
        while userLocation == nil && waitCount < 10 {
            debugLog("🏪 [POI] 等待用户位置... (\(waitCount + 1)/10)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            userLocation = locationManager.userLocation
            waitCount += 1
        }

        guard let location = userLocation else {
            debugLog("🏪 [POI] ❌ 无法获取用户位置，跳过POI搜索")
            isSearchingPOIs = false
            return
        }

        debugLog("🏪 [POI] 用户位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")

        // 搜索附近POI
        let allPOIs = await POISearchManager.shared.searchNearbyPOIs(center: location)

        // 根据密度等级限制POI数量
        let maxCount = currentDensityLevel.maxPOICount
        let limitedPOIs = Array(allPOIs.prefix(maxCount))
        nearbyPOIs = limitedPOIs

        debugLog("🏪 [POI] ✅ 找到 \(allPOIs.count) 个POI，根据密度等级(\(currentDensityLevel))显示 \(limitedPOIs.count) 个")
        for (index, poi) in limitedPOIs.enumerated() {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = userCLLocation.distance(from: poiLocation)
            debugLog("🏪 [POI]   #\(index + 1) \(poi.name) (\(poi.type.rawValue)) - 距离: \(String(format: "%.1f", distance))米")
        }

        // 启动POI接近检测定时器
        startPOIProximityTimer()

        isSearchingPOIs = false
    }

    /// 启动POI接近检测定时器（使用 .common 模式确保锁屏时继续运行）
    private func startPOIProximityTimer() {
        poiProximityTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkPOIProximity()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        poiProximityTimer = timer
        debugLog("🏪 [POI] ✅ 接近检测定时器已启动 (每2秒检测一次，触发范围: \(poiTriggerRadius)米)")
        debugLog("🏪 [POI] 当前共有 \(nearbyPOIs.count) 个POI待检测")
    }

    /// 检测POI接近
    private func checkPOIProximity() {
        // 修复：不再强制要求 isExploring，即使未探索也可以触发POI弹窗
        guard !showPOIPopup else {
            // 已经在显示弹窗，不重复触发
            return
        }
        
        guard let userLocation = locationManager.userLocation else {
            debugLog("🏪 [POI] 检测跳过：无用户位置")
            return
        }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        // 检查每个未搜刮的POI
        for poi in nearbyPOIs where !poi.isScavenged {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userCLLocation.distance(from: poiLocation)

            // 调试日志：显示所有POI的距离
            if distance <= poiTriggerRadius * 2 {
                debugLog("🏪 [POI] 距离检测：\(poi.name) - \(String(format: "%.1f", distance))米 (触发范围: \(poiTriggerRadius)米)")
            }

            if distance <= poiTriggerRadius {
                        // 进入POI范围
                        debugLog("🏪 [POI] ✅ 进入 \(poi.name) 范围（\(String(format: "%.0f", distance))米），触发弹窗")
                        triggerPOIPopup(poi: poi)
                        return
            }
        }
    }

    /// 触发POI弹窗
    private func triggerPOIPopup(poi: NearbyPOI) {
        currentPOI = poi
        showPOIPopup = true
        debugLog("🏪 [POI] ✅ 触发弹窗：\(poi.name)")
        debugLog("🏪 [POI] 弹窗状态 - showPOIPopup: \(showPOIPopup), currentPOI: \(poi.name)")
    }

    /// 清理POI和围栏
    private func cleanupPOIs() {
        // 停止定时器
        poiProximityTimer?.invalidate()
        poiProximityTimer = nil

        // 清空POI列表
        nearbyPOIs.removeAll()
        currentPOI = nil
        showPOIPopup = false

        debugLog("🏪 [POI] POI数据已清理")
    }

    // MARK: - POI 搜刮

    /// 执行搜刮（使用 AI 生成物品）
    /// - Parameter poi: 要搜刮的POI
    func scavengePOI(_ poi: NearbyPOI) async {
        debugLog("🏪 [搜刮] 开始搜刮：\(poi.name) (危险等级: \(poi.dangerLevel))")

        // Aether Energy gate: consume 1 energy before AI scan
        if !StoreKitManager.shared.isInfiniteEnergyEnabled {
            guard StoreKitManager.shared.consumeAetherEnergy() else {
                showEnergyDepletedAlert = true
                debugLog("🏪 [搜刮] ⚡ 能量不足，无法进行 AI 扫描")
                return
            }
        }

        // 生成物品数量（1-3件，高危地点可能更多）
        let baseCount = Int.random(in: 1...3)
        let bonusCount = poi.dangerLevel >= 4 ? Int.random(in: 0...1) : 0
        let itemCount = baseCount + bonusCount

        // 尝试使用 AI 生成物品
        let aiItems = await AIItemGenerator.shared.generateItems(for: poi, count: itemCount)

        // 如果 AI 失败，使用降级方案
        let generatedItems: [AIGeneratedItem]
        let isAIGenerated: Bool

        if let items = aiItems {
            generatedItems = items
            isAIGenerated = true
            debugLog("🏪 [搜刮] 使用 AI 生成的物品")
        } else {
            generatedItems = AIItemGenerator.shared.generateFallbackItems(for: poi, count: itemCount)
            isAIGenerated = false
            debugLog("🏪 [搜刮] 使用降级方案生成物品")
        }

        // 转换为 CollectedItem
        var collectedItems: [CollectedItem] = []

        for aiItem in generatedItems {
            // 随机品质
            let quality = randomQuality()

            // 使用基于分类的有效物品定义 ID（确保存在于数据库中）
            let definitionId = getDefinitionIdForCategory(aiItem.itemCategory)

            // 创建基础物品定义
            let definition = ItemDefinition(
                id: definitionId,
                name: aiItem.name,
                description: aiItem.story,
                category: aiItem.itemCategory,
                icon: getIconForCategory(aiItem.itemCategory),
                rarity: aiItem.itemRarity
            )

            // 创建收集物品（带 AI 信息）
            let item = CollectedItem(
                definition: definition,
                quality: quality,
                foundDate: Date(),
                quantity: 1,
                aiName: aiItem.name,
                aiStory: aiItem.story,
                isAIGenerated: isAIGenerated
            )
            collectedItems.append(item)

            debugLog("🏪 [搜刮] 获得：\(aiItem.name) [\(aiItem.rarity)] [\(quality.rawValue)] (定义ID: \(definitionId))")
        }

        // 将物品存入背包（重置/捕获存储满警告）
        debugLog("🏪 [搜刮] 正在保存 \(collectedItems.count) 个物品到背包...")
        InventoryManager.shared.storageFullWarning = false
        await InventoryManager.shared.addItems(
            collectedItems,
            sourceType: "scavenge",
            sourceSessionId: nil
        )
        let hadStorageWarning = InventoryManager.shared.storageFullWarning
        InventoryManager.shared.storageFullWarning = false
        debugLog("🏪 [搜刮] 物品保存完成")

        // 标记POI为已搜刮
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].isScavenged = true
        }

        // 设置搜刮结果
        latestScavengeResult = ScavengeResult(poi: poi, items: collectedItems, storageWarning: hadStorageWarning)

        // 关闭接近弹窗，显示结果
        showPOIPopup = false
        showScavengeResult = true

        debugLog("🏪 [搜刮] 完成，获得 \(collectedItems.count) 个物品 (AI生成: \(isAIGenerated))")
    }

    /// 随机生成品质
    private func randomQuality() -> ItemQuality {
        let random = Double.random(in: 0..<1)
        switch random {
        case 0..<0.05: return .pristine
        case 0.05..<0.30: return .good
        case 0.30..<0.70: return .worn
        case 0.70..<0.95: return .damaged
        default: return .ruined
        }
    }

    /// 根据物品分类获取有效的数据库物品定义 ID
    /// 这些 ID 必须存在于 item_definitions 表中
    private func getDefinitionIdForCategory(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "water_bottle"
        case .food: return "canned_beans"
        case .medical: return "bandage"
        case .material: return "scrap_metal"
        case .tool: return "rope"
        case .weapon: return "scrap_metal"
        case .other: return "scrap_metal"
        }
    }

    /// 根据物品分类获取图标
    private func getIconForCategory(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "gearshape.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "shield.fill"
        case .other: return "shippingbox.fill"
        }
    }

    /// 关闭POI弹窗（稍后再说）
    func dismissPOIPopup() {
        showPOIPopup = false
        currentPOI = nil
        debugLog("🏪 [POI] 用户选择稍后再说")
    }

    /// 关闭搜刮结果
    func dismissScavengeResult() {
        showScavengeResult = false
        latestScavengeResult = nil
    }

    // MARK: - Exploration Stats (DB-backed)

    /// 从数据库加载探索统计（支持时间过滤）
    /// - Parameter since: 可选的起始日期，nil 表示全部时间
    /// - Returns: (sessions: 总探索次数, totalDistance: 总距离, totalItems: 总物品数)
    func loadExplorationStats(since: Date? = nil) async -> (sessions: Int, totalDistance: Double, totalItems: Int) {
        guard let userId = AuthManager.shared.currentUser?.id else {
            return (0, 0, 0)
        }

        do {
            var query = supabase
                .from("exploration_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)

            if let since = since {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                query = query.gte("started_at", value: formatter.string(from: since))
            }

            let sessions: [ExplorationSession] = try await query.execute().value

            let totalDistance = sessions.reduce(0.0) { $0 + $1.totalDistance }
            let totalItems = sessions.reduce(0) { $0 + $1.itemsCount }

            debugLog("🔍 [探索统计] 查询完成 — 会话: \(sessions.count), 距离: \(String(format: "%.1f", totalDistance))m, 物品: \(totalItems)")

            return (sessions.count, totalDistance, totalItems)
        } catch {
            debugLog("🔍 [探索统计] 查询失败: \(error.localizedDescription)")
            return (0, 0, 0)
        }
    }

    /// 随机物品定义（用于探索奖励等非 AI 场景）
    /// ✅ Late-Binding: name 和 description 存储为 localization keys，在 ItemDefinition.localizedName 和 localizedDescription 中解析
    private func randomItemDefinition(rarity: ItemRarity) -> ItemDefinition {
        // 根据稀有度返回不同类型的物品
        switch rarity {
        case .common:
            let items = [
                ItemDefinition(id: "water_bottle", name: "item_pure_water", description: "item_pure_water_desc", category: .water, icon: "drop.fill", rarity: .common),
                ItemDefinition(id: "canned_beans", name: "item_canned_beans", description: "item_canned_beans_desc", category: .food, icon: "takeoutbag.and.cup.and.straw.fill", rarity: .common),
                ItemDefinition(id: "bandage", name: "item_bandage", description: "item_bandage_desc", category: .medical, icon: "bandage.fill", rarity: .common),
                ItemDefinition(id: "scrap_metal", name: "item_scrap_metal", description: "item_scrap_metal_desc", category: .material, icon: "gearshape.fill", rarity: .common),
                ItemDefinition(id: "rope", name: "item_rope", description: "item_rope_desc", category: .tool, icon: "line.diagonal", rarity: .common),
                ItemDefinition(id: "matches", name: "item_matches", description: "item_matches_desc", category: .tool, icon: "flame.fill", rarity: .common),
                ItemDefinition(id: "cloth", name: "item_cloth", description: "item_cloth_desc", category: .material, icon: "tshirt.fill", rarity: .common)
            ]
            return items.randomElement() ?? items[0]
        case .uncommon:
            let items = [
                ItemDefinition(id: "energy_drink", name: "item_energy_drink", description: "item_energy_drink_desc", category: .food, icon: "bolt.fill", rarity: .uncommon),
                ItemDefinition(id: "multi_tool", name: "item_multi_tool", description: "item_multi_tool_desc", category: .tool, icon: "wrench.and.screwdriver.fill", rarity: .uncommon),
                ItemDefinition(id: "med_kit_small", name: "item_small_first_aid_kit", description: "item_small_first_aid_kit_desc", category: .medical, icon: "cross.case.fill", rarity: .uncommon),
                ItemDefinition(id: "canned_fruit", name: "item_canned_fruit", description: "item_canned_fruit_desc", category: .food, icon: "leaf.fill", rarity: .uncommon),
                ItemDefinition(id: "duct_tape", name: "item_duct_tape", description: "item_duct_tape_desc", category: .material, icon: "rectangle.fill", rarity: .uncommon)
            ]
            return items.randomElement() ?? items[0]
        case .rare:
            let items = [
                ItemDefinition(id: "first_aid_kit", name: "item_first_aid_kit", description: "item_first_aid_kit_desc", category: .medical, icon: "cross.case.fill", rarity: .rare),
                ItemDefinition(id: "flashlight", name: "item_flashlight", description: "item_flashlight_desc", category: .tool, icon: "flashlight.on.fill", rarity: .rare),
                ItemDefinition(id: "canned_meat", name: "item_canned_meat", description: "item_canned_meat_desc", category: .food, icon: "fork.knife", rarity: .rare),
                ItemDefinition(id: "painkillers", name: "item_painkillers", description: "item_painkillers_desc", category: .medical, icon: "pills.fill", rarity: .rare),
                ItemDefinition(id: "batteries", name: "item_batteries", description: "item_batteries_desc", category: .material, icon: "battery.100", rarity: .rare)
            ]
            return items.randomElement() ?? items[0]
        case .epic:
            let items = [
                ItemDefinition(id: "antibiotics", name: "item_antibiotics", description: "item_antibiotics_desc", category: .medical, icon: "pills.fill", rarity: .epic),
                ItemDefinition(id: "radio", name: "item_radio", description: "item_radio_desc", category: .tool, icon: "antenna.radiowaves.left.and.right", rarity: .epic),
                ItemDefinition(id: "solar_charger", name: "item_solar_charger", description: "item_solar_charger_desc", category: .tool, icon: "sun.max.fill", rarity: .epic),
                ItemDefinition(id: "military_ration", name: "item_military_ration", description: "item_military_ration_desc", category: .food, icon: "bag.fill", rarity: .epic)
            ]
            return items.randomElement() ?? items[0]
        case .legendary:
            let items = [
                ItemDefinition(id: "hazmat_suit", name: "item_hazmat_suit", description: "item_hazmat_suit_desc", category: .tool, icon: "figure.dress.line.vertical.figure", rarity: .legendary),
                ItemDefinition(id: "night_vision", name: "item_night_vision", description: "item_night_vision_desc", category: .tool, icon: "eye.fill", rarity: .legendary),
                ItemDefinition(id: "surgical_kit", name: "item_surgical_kit", description: "item_surgical_kit_desc", category: .medical, icon: "scissors", rarity: .legendary),
                ItemDefinition(id: "water_purifier", name: "item_water_purifier", description: "item_water_purifier_desc", category: .tool, icon: "drop.triangle.fill", rarity: .legendary)
            ]
            return items.randomElement() ?? items[0]
        }
    }

    /// 计算到POI的距离
    func distanceToPOI(_ poi: NearbyPOI) -> Double {
        guard let userLocation = locationManager.userLocation else { return 0 }
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
        return userCLLocation.distance(from: poiLocation)
    }
}
