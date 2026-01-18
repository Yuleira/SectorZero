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
        print("🔍 [探索管理器] 初始化完成")
        print("🔍 [探索管理器] 配置：最大速度=\(String(format: "%.1f", maxAllowedSpeed))m/s (\(String(format: "%.0f", maxAllowedSpeed * 3.6))km/h)")
    }

    // MARK: - 公共方法

    /// 开始探索
    func startExploration() {
        guard canStartExploration() else {
            print("🔍 [探索] ❌ 无法开始探索")
            return
        }

        print("🔍 [探索] ✅ 开始探索")

        // 重置状态
        resetExplorationData()

        // 设置状态
        state = .exploring
        isExploring = true
        startTime = Date()

        // 确保定位服务运行
        if !locationManager.isUpdatingLocation {
            print("🔍 [探索] 启动定位服务")
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
            print("🔍 [探索] 当前密度等级: \(currentDensityLevel.localizedName)，最多显示 \(currentDensityLevel.maxPOICount) 个POI")

            // 3. 根据密度搜索并设置POI
            await searchAndSetupPOIs()
        }

        print("🔍 [探索] 所有定时器已启动")
    }

    /// 结束探索
    func stopExploration() async -> ExplorationResult? {
        guard isExploring else {
            print("🔍 [探索] ⚠️ 当前未在探索状态，无法结束")
            return nil
        }

        print("🔍 [探索] 🏁 结束探索，开始计算奖励...")

        state = .processing
        isExploring = false

        // 停止计时器
        stopTimers()

        // 清理POI和围栏
        cleanupPOIs()

        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0

        print("🔍 [探索] 探索数据 - 距离: \(String(format: "%.1f", currentDistance))m，时长: \(Int(duration))秒，采点: \(trackPoints.count)个")

        // 计算奖励等级
        let tier = RewardTier.from(distance: currentDistance)
        print("🔍 [探索] 奖励等级: \(tier.displayName)")

        // 生成奖励物品
        var collectedItems: [CollectedItem] = []
        if tier != .none {
            print("🔍 [探索] 开始生成奖励物品...")
            collectedItems = await RewardGenerator.shared.generateRewards(tier: tier)
            print("🔍 [探索] 生成了 \(collectedItems.count) 个物品")
        } else {
            print("🔍 [探索] 未达到奖励门槛，不生成物品")
        }

        // 保存探索记录到数据库
        print("🔍 [探索] 保存探索记录到数据库...")
        let sessionId = await saveExplorationSession(
            startTime: startTime ?? endTime,
            endTime: endTime,
            duration: Int(duration),
            distance: currentDistance,
            tier: tier,
            itemsCount: collectedItems.count
        )

        // 将物品保存到背包
        if let sessionId = sessionId, !collectedItems.isEmpty {
            print("🔍 [探索] 将物品保存到背包...")
            await InventoryManager.shared.addItems(
                collectedItems,
                sourceType: "exploration",
                sourceSessionId: sessionId
            )
            print("🔍 [探索] 物品已保存到背包")
        }

        // 构建结果
        let stats = ExplorationStats(
            totalDistance: currentDistance,
            duration: duration,
            pointsVerified: trackPoints.count,
            distanceRank: tier.displayName
        )

        let result = ExplorationResult(
            isSuccess: tier != .none,
            message: tier == .none ? NSLocalizedString("行走距离不足200米，未获得奖励", comment: "探索结果") : NSLocalizedString("探索成功！", comment: "探索结果"),
            itemsCollected: collectedItems,
            experienceGained: calculateExperience(tier: tier, distance: currentDistance),
            distanceWalked: currentDistance,
            stats: stats,
            startTime: startTime ?? endTime,
            endTime: endTime
        )

        latestResult = result
        state = .completed

        print("🔍 [探索] ✅ 探索完成 - 距离: \(String(format: "%.1f", currentDistance))m，等级: \(tier.displayName)，物品: \(collectedItems.count)个，经验: \(result.experienceGained)")

        return result
    }

    /// 取消探索（不保存记录）
    func cancelExploration() {
        guard isExploring else { return }

        print("🔍 [探索] ❌ 取消探索（不保存记录）")

        stopTimers()
        resetExplorationData()
        state = .idle
        isExploring = false
    }

    /// 因超速停止探索
    func stopExplorationDueToSpeeding() async {
        guard isExploring else { return }

        print("🔍 [探索] 🚫 因超速停止探索")

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
            distanceRank: NSLocalizedString("失败", comment: "探索等级")
        )

        let result = ExplorationResult(
            isSuccess: false,
            message: NSLocalizedString("探索失败：移动速度超过30km/h，可能使用了交通工具", comment: "探索结果"),
            itemsCollected: [],
            experienceGained: 0,
            distanceWalked: currentDistance,
            stats: stats,
            startTime: startTime ?? endTime,
            endTime: endTime
        )

        latestResult = result
        state = .failed(NSLocalizedString("速度过快", comment: "探索失败原因"))

        print("🔍 [探索] ❌ 探索失败 - 原因：超速")

        // 清理数据
        resetExplorationData()
    }

    // MARK: - 私有方法

    /// 检查是否可以开始探索
    private func canStartExploration() -> Bool {
        guard state == .idle || state == .completed || isFailedState() else {
            print("🔍 [探索] 当前状态不允许开始探索: \(state)")
            return false
        }

        guard locationManager.isAuthorized else {
            state = .failed(NSLocalizedString("需要定位权限", comment: "探索失败原因"))
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
        print("🔍 [探索] 探索数据已重置")
    }

    /// 启动时长计时器
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.currentDuration = Date().timeIntervalSince(start)
            }
        }
    }

    /// 启动采点定时器
    private func startSamplingTimer() {
        samplingTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.sampleCurrentLocation()
            }
        }
    }

    /// 启动速度检测定时器
    private func startSpeedCheckTimer() {
        // 每2秒检测一次速度
        speedCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkSpeed()
            }
        }
    }

    /// 检测速度
    private func checkSpeed() {
        guard isExploring else { return }

        // 从 locationManager 获取当前速度（CLLocation 提供的速度，单位是 m/s）
        guard let location = locationManager.userLocation else {
            return
        }

        // 创建 CLLocation 对象获取速度
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        // 使用 CLLocationManager 的实时速度
        // 注意：我们需要从 LocationManager 获取最新的 CLLocation 对象
        // 这里我们使用两点间距离和时间差来计算速度
        if let lastLocation = lastValidLocation, let lastTime = lastLocationTimestamp {
            let timeInterval = Date().timeIntervalSince(lastTime)
            if timeInterval > 0 {
                let distance = clLocation.distance(from: lastLocation)
                let speed = distance / timeInterval  // 米/秒
                currentSpeed = speed

                let speedKmh = speed * 3.6  // 转换为 km/h

                print("🔍 [速度检测] 当前速度: \(String(format: "%.1f", speedKmh))km/h (\(String(format: "%.2f", speed))m/s)")

                // 检查是否超速
                if speed > maxAllowedSpeed {
                    handleSpeeding(speed: speed)
                } else {
                    // 速度正常，清除警告
                    if speedWarning != nil {
                        print("🔍 [速度检测] ✅ 速度已恢复正常")
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
            speedWarning = String(format: NSLocalizedString("⚠️ 速度过快！当前: %.0fkm/h，限制: 30km/h", comment: "速度警告"), speedKmh)
            print("🔍 [速度检测] ⚠️ 超速警告：当前速度 \(String(format: "%.1f", speedKmh))km/h，开始倒计时")
        } else {
            // 持续超速，检查是否超过容忍时间
            let warningDuration = Date().timeIntervalSince(speedWarningStartTime!)

            if warningDuration >= speedWarningTimeout {
                // 超过10秒仍然超速，停止探索
                print("🔍 [速度检测] 🚫 超速超过\(Int(speedWarningTimeout))秒，停止探索")
                Task { [weak self] in
                    await self?.stopExplorationDueToSpeeding()
                }
            } else {
                // 更新警告消息，显示剩余时间
                let remainingTime = Int(speedWarningTimeout - warningDuration)
                speedWarning = String(format: NSLocalizedString("⚠️ 速度过快！%.0fkm/h > 30km/h，%d秒后停止", comment: "速度警告"), speedKmh, remainingTime)
                print("🔍 [速度检测] ⚠️ 持续超速 \(String(format: "%.1f", warningDuration))秒，剩余 \(remainingTime) 秒")
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
        print("🔍 [探索] 所有定时器已停止")
    }

    /// 采集当前位置
    private func sampleCurrentLocation() {
        guard isExploring else {
            print("🔍 [采点] ⚠️ 未在探索状态，跳过采点")
            return
        }

        guard let coordinate = locationManager.userLocation else {
            print("🔍 [采点] ⚠️ 当前位置为空，跳过采点")
            return
        }

        // 创建 CLLocation
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let now = Date()

        print("🔍 [采点] 尝试采集位置 - 坐标: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 精度: \(String(format: "%.1f", location.horizontalAccuracy))m")

        // 位置过滤
        if !validateLocation(location, timestamp: now) {
            print("🔍 [采点] ❌ 位置验证失败，跳过")
            return
        }

        // 计算与上一个有效点的距离
        var distanceIncrement: Double = 0
        if let last = lastValidLocation {
            distanceIncrement = location.distance(from: last)
            print("🔍 [采点] 距离增量: \(String(format: "%.2f", distanceIncrement))m")
        } else {
            print("🔍 [采点] 这是第一个有效点")
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

        print("🔍 [采点] ✅ 采点成功 #\(trackPoints.count) - 增加: \(String(format: "%.1f", distanceIncrement))m，总距离: \(String(format: "%.1f", currentDistance))m")
    }

    /// 位置有效性验证
    private func validateLocation(_ location: CLLocation, timestamp: Date) -> Bool {
        // 1. 精度过滤（负值表示无效）
        if location.horizontalAccuracy > minAccuracy || location.horizontalAccuracy < 0 {
            print("🔍 [探索] 精度不足: \(location.horizontalAccuracy)m，跳过")
            return false
        }

        // 2. 时间间隔过滤
        if let lastTime = lastLocationTimestamp {
            let interval = timestamp.timeIntervalSince(lastTime)
            if interval < minTimeInterval {
                print("🔍 [探索] 时间间隔不足: \(interval)s，跳过")
                return false
            }
        }

        // 3. 跳变过滤
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)
            if distance > maxJumpDistance {
                print("🔍 [探索] 位置跳变过大: \(distance)m，跳过")
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
            print("🔍 [探索] 未登录，无法保存探索记录")
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

            print("🔍 [探索] 探索记录保存成功")
            return response.first?.id
        } catch {
            print("🔍 [探索] 保存探索记录失败: \(error.localizedDescription)")
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
        print("🏪 [POI] 手动触发POI搜索...")
        await searchAndSetupPOIs()
    }

    /// 搜索并设置附近POI
    private func searchAndSetupPOIs() async {
        isSearchingPOIs = true
        print("🏪 [POI] 开始搜索附近POI...")

        // 等待用户位置准备好（最多等待5秒）
        var userLocation = locationManager.userLocation
        var waitCount = 0
        while userLocation == nil && waitCount < 10 {
            print("🏪 [POI] 等待用户位置... (\(waitCount + 1)/10)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            userLocation = locationManager.userLocation
            waitCount += 1
        }

        guard let location = userLocation else {
            print("🏪 [POI] ❌ 无法获取用户位置，跳过POI搜索")
            isSearchingPOIs = false
            return
        }

        print("🏪 [POI] 用户位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")

        // 搜索附近POI
        let allPOIs = await POISearchManager.shared.searchNearbyPOIs(center: location)

        // 根据密度等级限制POI数量
        let maxCount = currentDensityLevel.maxPOICount
        let limitedPOIs = Array(allPOIs.prefix(maxCount))
        nearbyPOIs = limitedPOIs

        print("🏪 [POI] ✅ 找到 \(allPOIs.count) 个POI，根据密度等级(\(currentDensityLevel.localizedName))显示 \(limitedPOIs.count) 个")
        for (index, poi) in limitedPOIs.enumerated() {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = userCLLocation.distance(from: poiLocation)
            print("🏪 [POI]   #\(index + 1) \(poi.name) (\(poi.type.rawValue)) - 距离: \(String(format: "%.1f", distance))米")
        }

        // 启动POI接近检测定时器
        startPOIProximityTimer()

        isSearchingPOIs = false
    }

    /// 启动POI接近检测定时器
    private func startPOIProximityTimer() {
        poiProximityTimer?.invalidate()
        poiProximityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkPOIProximity()
            }
        }
        print("🏪 [POI] ✅ 接近检测定时器已启动 (每2秒检测一次，触发范围: \(poiTriggerRadius)米)")
        print("🏪 [POI] 当前共有 \(nearbyPOIs.count) 个POI待检测")
    }

    /// 检测POI接近
    private func checkPOIProximity() {
        // 修复：不再强制要求 isExploring，即使未探索也可以触发POI弹窗
        guard !showPOIPopup else {
            // 已经在显示弹窗，不重复触发
            return
        }
        
        guard let userLocation = locationManager.userLocation else {
            print("🏪 [POI] 检测跳过：无用户位置")
            return
        }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        // 检查每个未搜刮的POI
        for poi in nearbyPOIs where !poi.isScavenged {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userCLLocation.distance(from: poiLocation)

            // 调试日志：显示所有POI的距离
            if distance <= poiTriggerRadius * 2 {
                print("🏪 [POI] 距离检测：\(poi.name) - \(String(format: "%.1f", distance))米 (触发范围: \(poiTriggerRadius)米)")
            }

            if distance <= poiTriggerRadius {
                        // 进入POI范围
                        print("🏪 [POI] ✅ 进入 \(poi.name) 范围（\(String(format: "%.0f", distance))米），触发弹窗")
                        triggerPOIPopup(poi: poi)
                        return
            }
        }
    }

    /// 触发POI弹窗
    private func triggerPOIPopup(poi: NearbyPOI) {
        currentPOI = poi
        showPOIPopup = true
        print("🏪 [POI] ✅ 触发弹窗：\(poi.name)")
        print("🏪 [POI] 弹窗状态 - showPOIPopup: \(showPOIPopup), currentPOI: \(poi.name)")
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

        print("🏪 [POI] POI数据已清理")
    }

    // MARK: - POI 搜刮

    /// 执行搜刮（使用 AI 生成物品）
    /// - Parameter poi: 要搜刮的POI
    func scavengePOI(_ poi: NearbyPOI) async {
        print("🏪 [搜刮] 开始搜刮：\(poi.name) (危险等级: \(poi.dangerLevel))")

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
            print("🏪 [搜刮] 使用 AI 生成的物品")
        } else {
            generatedItems = AIItemGenerator.shared.generateFallbackItems(for: poi, count: itemCount)
            isAIGenerated = false
            print("🏪 [搜刮] 使用降级方案生成物品")
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

            print("🏪 [搜刮] 获得：\(aiItem.name) [\(aiItem.rarity)] [\(quality.rawValue)] (定义ID: \(definitionId))")
        }

        // 将物品存入背包
        print("🏪 [搜刮] 正在保存 \(collectedItems.count) 个物品到背包...")
        await InventoryManager.shared.addItems(
            collectedItems,
            sourceType: "scavenge",
            sourceSessionId: nil
        )
        print("🏪 [搜刮] 物品保存完成")

        // 标记POI为已搜刮
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].isScavenged = true
        }

        // 设置搜刮结果
        latestScavengeResult = ScavengeResult(poi: poi, items: collectedItems)

        // 关闭接近弹窗，显示结果
        showPOIPopup = false
        showScavengeResult = true

        print("🏪 [搜刮] 完成，获得 \(collectedItems.count) 个物品 (AI生成: \(isAIGenerated))")
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
        print("🏪 [POI] 用户选择稍后再说")
    }

    /// 关闭搜刮结果
    func dismissScavengeResult() {
        showScavengeResult = false
        latestScavengeResult = nil
    }

    /// 随机物品定义（用于探索奖励等非 AI 场景）
    private func randomItemDefinition(rarity: ItemRarity) -> ItemDefinition {
        // 根据稀有度返回不同类型的物品
        switch rarity {
        case .common:
            let items = [
                ItemDefinition(id: "water_bottle", name: NSLocalizedString("纯净水", comment: "物品名称"), description: NSLocalizedString("一瓶还算干净的水", comment: "物品描述"), category: .water, icon: "drop.fill", rarity: .common),
                ItemDefinition(id: "canned_beans", name: NSLocalizedString("罐头豆子", comment: "物品名称"), description: NSLocalizedString("高蛋白食物", comment: "物品描述"), category: .food, icon: "takeoutbag.and.cup.and.straw.fill", rarity: .common),
                ItemDefinition(id: "bandage", name: NSLocalizedString("绷带", comment: "物品名称"), description: NSLocalizedString("简单的止血工具", comment: "物品描述"), category: .medical, icon: "bandage.fill", rarity: .common),
                ItemDefinition(id: "scrap_metal", name: NSLocalizedString("废金属", comment: "物品名称"), description: NSLocalizedString("可用于制造", comment: "物品描述"), category: .material, icon: "gearshape.fill", rarity: .common),
                ItemDefinition(id: "rope", name: NSLocalizedString("绳索", comment: "物品名称"), description: NSLocalizedString("多用途工具", comment: "物品描述"), category: .tool, icon: "line.diagonal", rarity: .common),
                ItemDefinition(id: "matches", name: NSLocalizedString("火柴", comment: "物品名称"), description: NSLocalizedString("生火必备", comment: "物品描述"), category: .tool, icon: "flame.fill", rarity: .common),
                ItemDefinition(id: "cloth", name: NSLocalizedString("布料", comment: "物品名称"), description: NSLocalizedString("可以缝补衣物", comment: "物品描述"), category: .material, icon: "tshirt.fill", rarity: .common)
            ]
            return items.randomElement()!
        case .uncommon:
            let items = [
                ItemDefinition(id: "energy_drink", name: NSLocalizedString("能量饮料", comment: "物品名称"), description: NSLocalizedString("提神醒脑的饮品", comment: "物品描述"), category: .food, icon: "bolt.fill", rarity: .uncommon),
                ItemDefinition(id: "multi_tool", name: NSLocalizedString("多功能工具", comment: "物品名称"), description: NSLocalizedString("集成多种工具的便携装置", comment: "物品描述"), category: .tool, icon: "wrench.and.screwdriver.fill", rarity: .uncommon),
                ItemDefinition(id: "med_kit_small", name: NSLocalizedString("小型急救包", comment: "物品名称"), description: NSLocalizedString("基本的医疗用品", comment: "物品描述"), category: .medical, icon: "cross.case.fill", rarity: .uncommon),
                ItemDefinition(id: "canned_fruit", name: NSLocalizedString("水果罐头", comment: "物品名称"), description: NSLocalizedString("补充维生素的好选择", comment: "物品描述"), category: .food, icon: "leaf.fill", rarity: .uncommon),
                ItemDefinition(id: "duct_tape", name: NSLocalizedString("万能胶带", comment: "物品名称"), description: NSLocalizedString("修复一切的神器", comment: "物品描述"), category: .material, icon: "rectangle.fill", rarity: .uncommon)
            ]
            return items.randomElement()!
        case .rare:
            let items = [
                ItemDefinition(id: "first_aid_kit", name: NSLocalizedString("急救包", comment: "物品名称"), description: NSLocalizedString("包含多种医疗用品", comment: "物品描述"), category: .medical, icon: "cross.case.fill", rarity: .rare),
                ItemDefinition(id: "flashlight", name: NSLocalizedString("手电筒", comment: "物品名称"), description: NSLocalizedString("黑暗中的光明", comment: "物品描述"), category: .tool, icon: "flashlight.on.fill", rarity: .rare),
                ItemDefinition(id: "canned_meat", name: NSLocalizedString("肉罐头", comment: "物品名称"), description: NSLocalizedString("珍贵的蛋白质来源", comment: "物品描述"), category: .food, icon: "fork.knife", rarity: .rare),
                ItemDefinition(id: "painkillers", name: NSLocalizedString("止痛药", comment: "物品名称"), description: NSLocalizedString("缓解疼痛", comment: "物品描述"), category: .medical, icon: "pills.fill", rarity: .rare),
                ItemDefinition(id: "batteries", name: NSLocalizedString("电池", comment: "物品名称"), description: NSLocalizedString("电子设备的能源", comment: "物品描述"), category: .material, icon: "battery.100", rarity: .rare)
            ]
            return items.randomElement()!
        case .epic:
            let items = [
                ItemDefinition(id: "antibiotics", name: NSLocalizedString("抗生素", comment: "物品名称"), description: NSLocalizedString("珍贵的药物", comment: "物品描述"), category: .medical, icon: "pills.fill", rarity: .epic),
                ItemDefinition(id: "radio", name: NSLocalizedString("对讲机", comment: "物品名称"), description: NSLocalizedString("远距离通讯设备", comment: "物品描述"), category: .tool, icon: "antenna.radiowaves.left.and.right", rarity: .epic),
                ItemDefinition(id: "solar_charger", name: NSLocalizedString("太阳能充电器", comment: "物品名称"), description: NSLocalizedString("可再生能源", comment: "物品描述"), category: .tool, icon: "sun.max.fill", rarity: .epic),
                ItemDefinition(id: "military_ration", name: NSLocalizedString("军用口粮", comment: "物品名称"), description: NSLocalizedString("高热量应急食品", comment: "物品描述"), category: .food, icon: "bag.fill", rarity: .epic)
            ]
            return items.randomElement()!
        case .legendary:
            let items = [
                ItemDefinition(id: "hazmat_suit", name: NSLocalizedString("防护服", comment: "物品名称"), description: NSLocalizedString("全身防护装备", comment: "物品描述"), category: .tool, icon: "figure.dress.line.vertical.figure", rarity: .legendary),
                ItemDefinition(id: "night_vision", name: NSLocalizedString("夜视仪", comment: "物品名称"), description: NSLocalizedString("在黑暗中看清一切", comment: "物品描述"), category: .tool, icon: "eye.fill", rarity: .legendary),
                ItemDefinition(id: "surgical_kit", name: NSLocalizedString("手术套件", comment: "物品名称"), description: NSLocalizedString("专业医疗设备", comment: "物品描述"), category: .medical, icon: "scissors", rarity: .legendary),
                ItemDefinition(id: "water_purifier", name: NSLocalizedString("净水器", comment: "物品名称"), description: NSLocalizedString("将任何水变成饮用水", comment: "物品描述"), category: .tool, icon: "drop.triangle.fill", rarity: .legendary)
            ]
            return items.randomElement()!
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
