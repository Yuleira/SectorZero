//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情视图（Day 29 重构版）
//  全屏地图 + 浮动工具栏 + 可折叠建筑列表面板
//

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryDetailView: View {

    // MARK: - Properties

    /// 领地数据
    let territory: Territory

    /// 删除回调
    var onDelete: (() -> Void)?

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - Managers

    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var territoryManager = TerritoryManager.shared

    // MARK: - State

    /// 底部面板展开状态
    @State private var isPanelExpanded = false

    /// 显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造流程）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 显示删除确认
    @State private var showDeleteAlert = false

    /// 待删除的建筑
    @State private var buildingToDelete: PlayerBuilding?

    /// 放置模式（位置优先流程：直接在地图上点击放置）
    @State private var isInPlacementMode = false

    /// 放置模式选中的位置
    @State private var placementSelectedLocation: CLLocationCoordinate2D?

    /// 放置模式验证错误
    @State private var showPlacementError = false
    @State private var placementErrorMessage = ""

    /// 预选位置（位置优先流程：先选位置，再选建筑）
    @State private var preSelectedLocation: CLLocationCoordinate2D?

    /// 显示删除领地确认
    @State private var showDeleteTerritoryAlert = false

    /// 领地重命名对话框
    @State private var showRenameDialog = false
    @State private var newTerritoryName = ""
    @State private var renameErrorMessage: String?
    @State private var currentDisplayName: String

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete
        // ✅ 修复：使用我们之前在 LanguageManager 里定义的 translate 助手方法
        // 把高级钥匙 (Resource) 转换成普通字符串 (String) 存入 State
        let resolvedName = LanguageManager.shared.translate(territory.displayName)
        self._currentDisplayName = State(initialValue: resolvedName)
    }
    // MARK: - Computed Properties

    /// 领地坐标
    private var coordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 放置模式地图点击回调（nil = 非放置模式）
    private var placementTapHandler: ((CLLocationCoordinate2D) -> Void)? {
        guard isInPlacementMode else { return nil }
        return { coordinate in
            self.handlePlacementTap(coordinate)
        }
    }

    /// 该领地的建筑列表
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 建筑模板字典（快速查找）
    private var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) })
    }
    
    /// 获取建筑的本地化名称
    private func getLocalizedBuildingName(for building: PlayerBuilding) -> String {
        _ = LanguageManager.shared.currentLocale
        // 优先使用 template 的本地化名称，否则使用 buildingName
        if let template = templateDict[building.templateId] {
            return template.resolvedLocalizedName
        } else {
            return building.buildingName
        }
    }
    
    /// 拆除确认消息文本
    @ViewBuilder
    private var demolishMessage: some View {
        if let building = buildingToDelete {
            let locale = LanguageManager.shared.currentLocale
            let buildingName = getLocalizedBuildingName(for: building)
            Text(String(format: String(localized: "building_demolish_message %@", locale: locale), buildingName))
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景：全屏地图
            TerritoryMapView(
                territoryCoordinates: coordinates,
                buildings: territoryBuildings,
                buildingTemplates: templateDict,
                onTap: placementTapHandler,
                selectedPlacementLocation: placementSelectedLocation
            )
            .ignoresSafeArea()
            
            // 顶部浮动工具栏
            VStack {
                if !isInPlacementMode {
                    TerritoryToolbarView(
                        territoryName: currentDisplayName,
                        onBack: {
                            dismiss()
                        },
                        onTitleTap: {
                            newTerritoryName = currentDisplayName
                            renameErrorMessage = nil
                            showRenameDialog = true
                        }
                    )

                    // 放置模式提示横幅（仅在选中模板时显示）
                    if selectedTemplateForConstruction != nil {
                        placementModeBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTemplateForConstruction != nil)
                    }
                } else {
                    // 放置模式顶栏：Cancel + Tap to place building
                    placementModeTopBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // 放置模式确认按钮
            if isInPlacementMode, placementSelectedLocation != nil {
                VStack {
                    Spacer()
                    Button {
                        confirmPlacementLocation()
                    } label: {
                        Text(LocalizedString.buildingConfirmLocation)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.primary)
                                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 底部建筑列表面板（放置模式时隐藏）
            if !isInPlacementMode {
                VStack {
                    Spacer()
                    buildingListPanel
                }
            }
        }
        .task {
            // 加载建筑模板和该领地的建筑
            if buildingManager.buildingTemplates.isEmpty {
                await buildingManager.loadTemplates()
            }
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        }
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(territoryId: territory.id) { template in
                selectedTemplateForConstruction = template
            }
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: coordinates,
                existingBuildings: territoryBuildings,
                initialLocation: preSelectedLocation
            )
        }
        .alert(LocalizedString.buildingLocationInvalid, isPresented: $showPlacementError) {
            Button(LocalizedString.commonConfirm, role: .cancel) {}
        } message: {
            Text(placementErrorMessage)
        }
        .sheet(isPresented: $showRenameDialog) {
            renameSheet
        }
        .alert(LocalizedString.buildingDemolishConfirm, isPresented: $showDeleteAlert) {
            Button(LocalizedString.commonCancel, role: .cancel) {
                buildingToDelete = nil
            }
            Button(LocalizedString.buildingDemolish, role: .destructive) {
                if let building = buildingToDelete {
                    Task {
                        await demolishBuilding(building)
                    }
                }
            }
        } message: {
            demolishMessage
        }
        .alert(LocalizedString.territoryDeleteConfirmTitle, isPresented: $showDeleteTerritoryAlert) {
            Button(LocalizedString.commonCancel, role: .cancel) {}
            Button(LocalizedString.commonDelete, role: .destructive) {
                Task {
                    await deleteTerritory()
                }
            }
        } message: {
            Text(LocalizedString.territoryDeleteConfirmMessage)
        }
    }

    // MARK: - Subviews

    /// 放置模式提示横幅 — Tactical Aurora
    private var placementModeBanner: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.neonGreen)

            Text(LocalizedString.buildingSelectLocation)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.neonGreen.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 放置模式顶栏
    private var placementModeTopBar: some View {
        HStack {
            // 取消按钮
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isInPlacementMode = false
                    placementSelectedLocation = nil
                }
            } label: {
                Text(LocalizedString.commonCancel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
            }

            Spacer()

            // 提示文字
            Text(LocalizedString.buildingTapToPlace)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )

            Spacer()

            // 占位（对称布局）
            Color.clear.frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// 建筑列表面板（底部可折叠）
    private var buildingListPanel: some View {
        VStack(spacing: 0) {
            // 拖动条
            RoundedRectangle(cornerRadius: 3)
                .fill(ApocalypseTheme.textMuted.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPanelExpanded.toggle()
                    }
                }
            
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.territoryBuildings)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(String(format: String(localized: "building_count_format %lld", locale: LanguageManager.shared.currentLocale), territoryBuildings.count))
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                
                Spacer()

                // 建造入口 + 调试按钮 + 展开/收起
                HStack(spacing: 8) {
                    // Build 按钮（模板优先流程）
                    Button {
                        preSelectedLocation = nil
                        showBuildingBrowser = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(LocalizedString.buildingBuild)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary)
                        )
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    // 建造位置按钮 — 先选位置，再选建筑
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            placementSelectedLocation = nil
                            isInPlacementMode = true
                        }
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }

                    // 删除领地按钮
                    Button {
                        showDeleteTerritoryAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }

                    // 展开/收起按钮
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isPanelExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // 建筑列表
            if isPanelExpanded {
                ScrollView {
                    if territoryBuildings.isEmpty {
                        emptyBuildingState
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(territoryBuildings) { building in
                                TerritoryBuildingRow(
                                    building: building,
                                    template: templateDict[building.templateId],
                                    onUpgrade: {
                                        handleUpgrade(building)
                                    },
                                    onDemolish: {
                                        buildingToDelete = building
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(.bottom, isPanelExpanded ? 0 : 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
        )
        .frame(height: isPanelExpanded ? nil : 120)
    }
    
    /// 空状态视图
    private var emptyBuildingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(LocalizedString.territoryNoBuildings)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            Text(LocalizedString.territoryBuildHint)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    /// 重命名面板
    private var renameSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField(
                        String(localized: "territory_rename_placeholder"),
                        text: $newTerritoryName
                    )
                    .textFieldStyle(.roundedBorder)
                }

                if let error = renameErrorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(ApocalypseTheme.danger)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(String(localized: "territory_rename"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) {
                        showRenameDialog = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) {
                        renameTerritory()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// 处理建筑升级
    private func handleUpgrade(_ building: PlayerBuilding) {
        Task {
            let result = await buildingManager.upgradeBuilding(buildingId: building.id)
            switch result {
            case .success(let upgraded):
                print("🏗️ 升级成功: \(upgraded.buildingName) -> Lv.\(upgraded.level)")
            case .failure(let error):
                print("🏗️ 升级失败: \(error)")
                buildingManager.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// 删除领地
    private func deleteTerritory() async {
        let success = await territoryManager.deleteTerritory(territoryId: territory.id)
        if success {
            onDelete?()
            dismiss()
        }
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        let success = await buildingManager.demolishBuilding(buildingId: building.id)
        
        if success {
            print("🏗️ 拆除成功: \(building.buildingName)")
        } else {
            print("🏗️ 拆除失败: \(building.buildingName)")
        }
        
        buildingToDelete = nil
    }

    /// 处理放置模式地图点击
    private func handlePlacementTap(_ coordinate: CLLocationCoordinate2D) {
        let isInside = isPointInPolygon(point: coordinate, polygon: coordinates)
        if isInside {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                placementSelectedLocation = coordinate
            }
        } else {
            placementErrorMessage = String(localized: "building_location_outside_territory")
            showPlacementError = true
        }
    }

    /// 确认放置位置，进入建筑选择
    private func confirmPlacementLocation() {
        guard let location = placementSelectedLocation else { return }
        preSelectedLocation = location
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isInPlacementMode = false
            placementSelectedLocation = nil
        }
        showBuildingBrowser = true
    }

    /// 射线法判断点是否在多边形内
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
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
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }

    /// 执行重命名操作
    private func renameTerritory() {
        let trimmedName = newTerritoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            renameErrorMessage = String(localized: "territory_rename_required")
            return
        }

        Task {
            let success = await territoryManager.updateTerritoryName(territoryId: territory.id, newName: trimmedName)
            if success {
                currentDisplayName = trimmedName
                renameErrorMessage = nil
                showRenameDialog = false
            } else {
                renameErrorMessage = String(localized: "territory_rename_failed")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "user-id",
            name: "Test Territory",
            path: [
                ["lat": 31.2304, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4747],
                ["lat": 31.2324, "lon": 121.4737],
                ["lat": 31.2314, "lon": 121.4727]
            ],
            area: 1500,
            pointCount: 15,
            isActive: true,
            completedAt: "2026-01-07T10:30:00Z",
            startedAt: "2026-01-07T10:25:00Z",
            createdAt: "2026-01-07T10:30:00Z",
            distanceWalked: 320
        )
    )
}
