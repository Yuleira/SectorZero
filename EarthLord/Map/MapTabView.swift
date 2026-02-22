//
//  MapTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//
//  地图页面
//  显示末世风格地图、用户位置、定位权限处理
//

import SwiftUI
import CoreLocation
import Combine
import Supabase

/// 地图页面主视图
struct MapTabView: View {

    // MARK: - 状态属性

    /// 定位管理器
    @ObservedObject private var locationManager = LocationManager.shared

    /// 领地管理器
    @ObservedObject private var territoryManager = TerritoryManager.shared

    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 探索管理器
    @ObservedObject private var explorationManager = ExplorationManager.shared

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 请求地图居中到用户位置的版本号（每次点击 Locate 递增，供 MapViewRepresentable 响应）
    @State private var centerToUserRequestVersion = 0

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 圈地开始时间
    @State private var trackingStartTime: Date?

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传成功提示
    @State private var showUploadSuccess = false

    /// 上传错误信息
    @State private var uploadError: String?

    /// 领地验证失败弹窗
    @State private var showValidationFailedAlert = false

    /// 验证失败原因
    @State private var validationFailedReason: String = ""

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?

    /// 是否显示探索进行中的悬浮UI
    @State private var showExplorationOverlay = true

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告横幅
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    /// Path restore dialog state
    @State private var savedPathToRestore: [CLLocationCoordinate2D]?
    @State private var showPathRestoreDialog = false

    /// 当前用户ID（计算属性）
    private var currentUserId: String? {
        authManager.currentUser?.id.uuidString
    }

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 根据授权状态显示不同内容
            if locationManager.isDenied {
                LocationDeniedView()
            } else {
                mapContent  // ← 临时注释
            }
        }
        .onAppear {
            handleOnAppear()
            checkForSavedPath()
        }
        .confirmationDialog(
            "Unfinished Walk",
            isPresented: $showPathRestoreDialog,
            titleVisibility: .visible
        ) {
            Button("Restore") {
                if let path = savedPathToRestore, !path.isEmpty {
                    locationManager.resumePathTracking(with: path)
                    trackingStartTime = Date()
                }
                savedPathToRestore = nil
            }
            Button("Discard", role: .destructive) {
                locationManager.clearSavedPath()
                savedPathToRestore = nil
            }
            Button("Cancel", role: .cancel) {
                savedPathToRestore = nil
            }
        } message: {
            Text("We found an unfinished walk from earlier. Restore it?")
        }
    }

    // MARK: - 子视图

    /// 地图内容视图
    private var mapContent: some View {
        ZStack {
        
            // 末世风格地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                centerToUserRequestVersion: centerToUserRequestVersion,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                showsUserLocation: true,
                territories: territories,
                currentUserId: authManager.currentUser?.id.uuidString,
                nearbyPOIs: explorationManager.nearbyPOIs
            )
            .ignoresSafeArea()

            // 顶部警告横幅
            VStack {
                // Day 19: 碰撞预警横幅（优先显示，分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 速度警告
                if let warning = locationManager.speedWarning, !showCollisionWarning {
                    speedWarningBanner(warning)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
            .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)
            .animation(.easeInOut(duration: 0.3), value: showValidationBanner)

            // 底部按钮栏
            VStack {
                Spacer()

                // 探索进行中悬浮UI
                if explorationManager.isExploring && showExplorationOverlay {
                    explorationProgressOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                // 水平按钮栏
                HStack(spacing: 12) {
                    // 圈地按钮
                    trackingButton

                    // 定位按钮
                    locateButton

                    // 探索按钮
                    explorationButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)  // 避开 TabBar
            }
            .animation(.spring(response: 0.3), value: explorationManager.isExploring)

            // 上传成功提示
            if showUploadSuccess {
                uploadSuccessBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 上传错误提示
            if let error = uploadError {
                uploadErrorBanner(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 加载指示器（首次定位时显示）
            if !hasLocatedUser && locationManager.isAuthorized {
                loadingOverlay
            }

            // POI接近弹窗
            if explorationManager.showPOIPopup, let poi = explorationManager.currentPOI {
                VStack {
                    Spacer()
                    POIProximityPopup(
                        poi: poi,
                        distance: explorationManager.distanceToPOI(poi),
                        onScavenge: {
                            Task {
                                await explorationManager.scavengePOI(poi)
                            }
                        },
                        onDismiss: {
                            explorationManager.dismissPOIPopup()
                        }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: explorationManager.showPOIPopup)
            }

            // 搜刮结果视图
            if explorationManager.showScavengeResult, let result = explorationManager.latestScavengeResult {
                ScavengeResultView(
                    result: result,
                    onDismiss: {
                        explorationManager.dismissScavengeResult()
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: explorationManager.showScavengeResult)
            }
        }
        .onChange(of: locationManager.speedWarning) { oldValue, newValue in
            // 速度警告 3 秒后自动消失
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if locationManager.speedWarning == newValue {
                        locationManager.clearSpeedWarning()
                    }
                }
            }
        }
        .onReceive(locationManager.$isPathClosed) { isClosed in
            // 监听闭环状态，闭环后自动上传（不需要手动确认）
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if locationManager.territoryValidationPassed {
                        // 验证通过 → 自动上传
                        Task {
                            await uploadCurrentTerritory()
                        }
                    } else {
                        // 验证失败 → 仍然累计行走距离
                        let distance = locationManager.totalDistance
                        Task {
                            await territoryManager.addCumulativeDistance(distance)
                        }
                        // 保存失败原因，显示持久 alert
                        validationFailedReason = locationManager.territoryValidationError ?? NSLocalizedString("map_validation_failed", comment: "")
                        showValidationFailedAlert = true
                        // 停止追踪（清除路径数据）
                        locationManager.stopPathTracking()
                        stopCollisionMonitoring()
                        trackingStartTime = nil
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showUploadSuccess)
        .animation(.easeInOut(duration: 0.3), value: uploadError)
        .animation(.easeInOut(duration: 0.3), value: locationManager.territoryValidationPassed)
        .alert(Text(LocalizedString.energyDepletedTitle),
               isPresented: $explorationManager.showEnergyDepletedAlert) {
            NavigationLink(destination: StoreView(initialSection: .energy)) {
                Text(LocalizedString.energyDepletedGoToStore)
            }
            Button(String(localized: LocalizedString.commonCancel), role: .cancel) {}
        } message: {
            Text(LocalizedString.energyDepletedMessage)
        }
        .alert(NSLocalizedString("map_validation_failed", comment: "Territory validation failed"),
               isPresented: $showValidationFailedAlert) {
            Button(NSLocalizedString("common_ok", comment: "OK"), role: .cancel) {}
        } message: {
            Text(validationFailedReason)
        }
        .alert(
            NSLocalizedString("location_precise_required_title", comment: "Precise Location Required"),
            isPresented: Binding(
                get: { locationManager.needsPreciseLocation },
                set: { _ in }
            )
        ) {
            Button(NSLocalizedString("location_open_settings", comment: "Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("common_cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("location_precise_required_message", comment: "Territory claiming requires precise location. Please go to Settings > Privacy & Security > Location Services and enable Precise Location for this app."))
        }
    }

    /// 速度警告横幅
    private func speedWarningBanner(_ warning: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))

            Text(warning)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(locationManager.isTracking ? ApocalypseTheme.warning : Color.red)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .padding(.top, 60)  // 避开状态栏
    }

    /// Day 19: 碰撞预警横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 60)

            Spacer()
        }
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text(String(format: NSLocalizedString("map_claim_success_format", comment: ""), locationManager.calculatedArea))
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "map_validation_failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
    }

    /// 圈地按钮
    private var trackingButton: some View {
        Button {
            toggleTracking()
        } label: {
            VStack(spacing: 6) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 20, weight: .semibold))

                // 文字
                Text(claimingButtonTitle)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    /// 确认登记按钮
    private var confirmButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(String(localized: "map_confirm_register"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(isUploading)
        .opacity(isUploading ? 0.7 : 1.0)
    }

    /// 上传成功横幅
    private var uploadSuccessBanner: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)

                Text(LocalizedString.mapTerritoryRegistered)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
            .padding(.bottom, 120)
        }
    }

    /// 上传错误横幅
    private func uploadErrorBanner(_ error: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)

                Text(error)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.red)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
            .padding(.bottom, 120)
        }
    }

    /// 定位按钮
    private var locateButton: some View {
        Button {
            centerToUserLocation()
        } label: {
            VStack(spacing: 6) {
                // 定位图标
                Image(systemName: locationIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text(LocalizedString.mapLocate)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    /// 探索按钮
    private var explorationButton: some View {
        Button {
            handleExplorationButtonTap()
        } label: {
            VStack(spacing: 6) {
                // 图标或加载指示器
                if explorationManager.state == .processing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                        .frame(height: 20)
                } else {
                    Image(systemName: explorationManager.isExploring ? "stop.fill" : "binoculars.fill")
                        .font(.system(size: 20, weight: .semibold))
                }

                Text(explorationButtonTitle)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(explorationManager.isExploring ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(!locationManager.isAuthorized || explorationManager.state == .processing)
        .opacity(locationManager.isAuthorized && explorationManager.state != .processing ? 1.0 : 0.5)
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(
                    result: result,
                    onDismiss: {
                        showExplorationResult = false
                        explorationResult = nil
                    },
                    onRetry: nil as (() -> Void)?
                )
            }
        }
    }

    /// 探索按钮标题 (Late-Binding: evaluated at render time)
    private var explorationButtonTitle: LocalizedStringResource {
        switch explorationManager.state {
        case .exploring:
            return "map_stop_explore"
        case .processing:
            return "map_calculating"
        default:
            return "map_explore"
        }
    }
    
    /// 领地圈占按钮标题 (Late-Binding: evaluated at render time)
    private var claimingButtonTitle: LocalizedStringResource {
        locationManager.isTracking ? "map_stop_claiming" : "map_start_claiming"
    }

    /// 处理探索按钮点击
    private func handleExplorationButtonTap() {
        if explorationManager.isExploring {
            // 结束探索
            Task {
                explorationResult = await explorationManager.stopExploration()
                if explorationResult != nil {
                    showExplorationResult = true
                }
            }
        } else {
            // 开始探索模式（设置状态 + 搜索POI + 启动定位）
            showExplorationOverlay = true
            explorationManager.startExploration()
        }
    }

    /// 加载中覆盖层
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text(String(localized: "map_locating"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
        )
    }

    /// 探索进行中悬浮UI
    private var explorationProgressOverlay: some View {
        HStack(spacing: 20) {
            // 距离显示
            VStack(spacing: 4) {
                Text(String(format: "%.0f", explorationManager.currentDistance))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(String(localized: "unit_meter"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // 时间显示
            VStack(spacing: 4) {
                Text(formatExplorationDuration(explorationManager.currentDuration))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(String(localized: "map_duration"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            // 关闭按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showExplorationOverlay = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }

    /// 格式化探索时长
    private func formatExplorationDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 计算属性

    /// 定位按钮图标
    private var locationIcon: String {
        if !locationManager.isAuthorized {
            return "location.slash"
        } else if hasLocatedUser {
            return "location.fill"
        } else {
            return "location"
        }
    }

    /// 定位按钮图标颜色
    private var locationIconColor: Color {
        if !locationManager.isAuthorized {
            return ApocalypseTheme.textMuted
        } else if hasLocatedUser {
            return ApocalypseTheme.primary
        } else {
            return ApocalypseTheme.textPrimary
        }
    }

    // MARK: - 方法

    /// 页面出现时处理
    private func checkForSavedPath() {
        guard !locationManager.isTracking else { return }
        if let saved = locationManager.loadSavedPath(), !saved.isEmpty {
            savedPathToRestore = saved
            showPathRestoreDialog = true
        }
    }

    private func handleOnAppear() {
        debugLog("🗺️ [地图页面] 页面出现")

        // 检查授权状态
        if locationManager.isNotDetermined {
            // 首次使用，请求权限
            debugLog("🗺️ [地图页面] 首次使用，请求定位权限")
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            // 已授权，开始定位
            debugLog("🗺️ [地图页面] 已授权，开始定位")
            locationManager.startUpdatingLocation()
        }

        // 加载所有领地
        Task {
            await loadTerritories()
        }
    }

    /// 居中到用户位置（不重置 hasLocatedUser，避免 “Locating...” 无法关闭）
    private func centerToUserLocation() {
        debugLog("🗺️ [地图页面] 用户点击定位按钮")
        centerToUserRequestVersion += 1
        if !locationManager.isUpdatingLocation {
            locationManager.startUpdatingLocation()
        }
    }

    /// 切换圈地状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止圈地 — 累计行走距离（即使未闭环）
            debugLog("🗺️ [地图页面] 用户停止圈地")
            let distance = locationManager.totalDistance
            Task {
                await territoryManager.addCumulativeDistance(distance)
            }
            stopCollisionMonitoring()  // 完全停止，清除警告
            locationManager.stopPathTracking()
            trackingStartTime = nil
        } else {
            // Day 19: 开始圈地前检测起始点
            startClaimingWithCollisionCheck()
        }
    }


    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let _ = currentUserId else {
            withAnimation {
                uploadError = NSLocalizedString("error_not_logged_in", comment: "")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { uploadError = nil }
            }
            return
        }

        guard let _ = locationManager.userLocation else {
            withAnimation {
                uploadError = NSLocalizedString("map_waiting_for_gps", comment: "")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { uploadError = nil }
            }
            return
        }

        // 直接开始圈地（进入他人领地只警告，不阻止）
        TerritoryLogger.shared.log("开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次（使用 .common 模式确保锁屏/后台时仍触发）
        let timer = Timer(timeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }
        RunLoop.main.add(timer, forMode: .common)
        collisionCheckTimer = timer

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 进入他人领地 — 只警告，不终止圈地
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)
            TerritoryLogger.shared.log("进入他人领地范围，警告提醒", type: .warning)
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // 防止重复上传
        guard !isUploading else {
            debugLog("🗺️ [地图页面] ⚠️ 已在上传中，跳过重复调用")
            return
        }

        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            withAnimation {
                uploadError = "map_validation_failed_upload"
            }
            // 8 秒后清除错误（给用户足够时间阅读）
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation {
                    uploadError = nil
                }
            }
            return
        }

        // 保存当前数据（因为 stopPathTracking 会清除）
        let coordinates = locationManager.pathCoordinates
        let area = locationManager.calculatedArea
        let startTime = trackingStartTime ?? Date()
        let distance = locationManager.totalDistance

        isUploading = true

        do {
            try await territoryManager.uploadTerritory(
                coordinates: coordinates,
                area: area,
                startTime: startTime,
                distanceWalked: distance
            )

            // 上传成功
            debugLog("🗺️ [地图页面] 领地上传成功")

            // 累计行走距离
            await territoryManager.addCumulativeDistance(distance)

            // 停止碰撞监控
            stopCollisionMonitoring()

            // 停止追踪（会重置所有状态）
            locationManager.stopPathTracking()
            trackingStartTime = nil

            // 显示成功提示
            withAnimation {
                showUploadSuccess = true
            }

            // 3 秒后隐藏成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showUploadSuccess = false
                }
            }

            // 刷新领地列表
            await loadTerritories()

        } catch {
            debugLog("🗺️ [地图页面] 领地上传失败: \(error.localizedDescription)")

            // 显示错误提示
            withAnimation {
                let format = NSLocalizedString("map_upload_failed_format", comment: "Upload failed")
                uploadError = String(format: format, error.localizedDescription)
            }

            // 8 秒后清除错误（给用户足够时间阅读）
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation {
                    uploadError = nil
                }
            }
        }

        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
            debugLog("🗺️ [地图页面] 加载了 \(territories.count) 个领地")
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
            debugLog("🗺️ [地图页面] 加载领地失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 权限被拒绝视图

/// 定位权限被拒绝时显示的提示视图
struct LocationDeniedView: View {

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text(String(localized: "map_location_unavailable"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明文字
            Text(String(localized: "map_location_permission_desc"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 前往设置按钮
            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
            Text(String(localized: "map_go_to_settings"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.cardBackground)
        )
        .padding(.horizontal, 24)
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
}
