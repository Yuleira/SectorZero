//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建筑放置确认视图
//  显示资源需求、选择位置、确认建造
//

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territoryId: String
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    
    // MARK: - State
    
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isConstructing = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed Properties
    
    /// 当前资源汇总
    private var playerResources: [String: Int] {
        inventoryManager.getResourceSummary()
    }
    
    /// 建筑模板字典
    private var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) })
    }
    
    /// 是否所有资源都足够（使用归一化 ID 与 getResourceSummary 的 key 对齐）
    private var hasAllResources: Bool {
        for (resourceId, required) in template.requiredResources {
            let available = playerResources[resourceId.lowercased()] ?? 0
            if available < required {
                return false
            }
        }
        return true
    }
    
    /// 是否可以建造
    private var canConstruct: Bool {
        hasAllResources && selectedLocation != nil
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        buildingInfoCard
                        resourceRequirementsCard
                        locationSelectionCard
                        constructButton
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(LocalizedString.buildingPlaceTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            if selectedLocation == nil, let first = territoryCoordinates.first {
                selectedLocation = first
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            BuildingLocationPickerView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: existingBuildings,
                buildingTemplates: templateDict,
                onLocationSelected: { location in
                    selectedLocation = location
                }
            )
        }
        .alert("building_construction_success", isPresented: $showSuccessAlert) {
            Button(LocalizedString.commonConfirm) {
                dismiss()
            }
        } message: {
            Text(String(format: String(localized: "building_construction_started_format %@", locale: LanguageManager.shared.currentLocale), template.resolvedLocalizedName))
        }
        .alert("building_construction_failed", isPresented: $showErrorAlert) {
            Button(LocalizedString.commonConfirm, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    /// 建筑信息卡片
    private var buildingInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(template.category.accentColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(ApocalypseTheme.primary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(template.localizedName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    HStack(spacing: 8) {
                        Text(template.category.localizedName)
                            .font(.system(size: 13))
                            .foregroundColor(template.category.accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text("•")
                            .foregroundColor(ApocalypseTheme.textMuted)
                        
                        Text(String(format: String(localized: "building_tier_format %lld", locale: LanguageManager.shared.currentLocale), template.tier))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                
                Spacer()
            }
            
            Text(template.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.buildingBuildTime)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("\(template.buildTimeSeconds)s")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.buildingMaxPerTerritory)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("\(template.maxPerTerritory)")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }
    
    /// 资源需求卡片
    private var resourceRequirementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行（仅图标 + 文案，不与状态徽章挤在一起）
            HStack(spacing: 8) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(ApocalypseTheme.primary)
                
                Text(LocalizedString.inventoryResources)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer()
            }
            
            // 资源状态：单独一行，与标题、列表分离，避免与图标重叠
            HStack {
                Spacer()
                if hasAllResources {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(ApocalypseTheme.success)
                        Text(LocalizedString.buildingResourcesSufficient)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundColor(ApocalypseTheme.success)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                        Text(LocalizedString.insufficientResources)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ApocalypseTheme.danger))
                }
            }
            
            // 资源列表
            VStack(spacing: 12) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    let required = template.requiredResources[resourceId] ?? 0
                    let available = playerResources[resourceId.lowercased()] ?? 0
                    ResourceRow(
                        resourceId: resourceId,
                        requiredAmount: required,
                        availableAmount: available
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }
    
    /// 位置选择卡片
    private var locationSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(ApocalypseTheme.primary)
                
                Text(LocalizedString.buildingSelectLocation)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                if selectedLocation != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(ApocalypseTheme.success)
                        Text(LocalizedString.buildingLocationSelected)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .foregroundColor(ApocalypseTheme.success)
                }
            }
            
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(ApocalypseTheme.primary)
                    
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedString.buildingLocationCoordinates)
                                .font(.system(size: 13, weight: .medium))
                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.system(size: 11))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    } else {
                        Text(LocalizedString.buildingTapToSelectLocation)
                            .font(.system(size: 15, weight: .medium))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(ApocalypseTheme.cardBackground.opacity(0.5)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(ApocalypseTheme.cardBackground))
    }
    
    /// 建造按钮
    private var constructButton: some View {
        Button {
            Task {
                await handleConstruction()
            }
        } label: {
            HStack(spacing: 12) {
                if isConstructing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                    Text(LocalizedString.buildingConfirmConstruction)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(canConstruct ? ApocalypseTheme.primary : ApocalypseTheme.textMuted))
        }
        .disabled(!canConstruct || isConstructing)
        .opacity(canConstruct && !isConstructing ? 1.0 : 0.6)
    }
    
    // MARK: - Actions
    
    /// 处理建造
    private func handleConstruction() async {
        guard let location = selectedLocation else {
            errorMessage = String(localized: "building_error_no_location", locale: LanguageManager.shared.currentLocale)
            showErrorAlert = true
            return
        }
        
        isConstructing = true
        defer { isConstructing = false }
        
        // ⚠️ location 来自地图选择，已经是 GCJ-02，直接保存
        let result = await buildingManager.startConstruction(
            templateId: template.templateId,
            territoryId: territoryId,
            location: location
        )
        
        switch result {
        case .success(let building):
            print("🏗️ [建造] 成功: \(building.buildingName)")
            showSuccessAlert = true
            
        case .failure(let error):
            print("🏗️ [建造] 失败: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    let coords = [
        CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4747),
        CLLocationCoordinate2D(latitude: 31.2324, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4727)
    ]
    
    let template = BuildingTemplate(
        id: UUID(),
        templateId: "campfire",
        name: "building_name_campfire",
        category: .survival,
        tier: 1,
        description: "building_description_campfire",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 60,
        maxPerTerritory: 3,
        maxLevel: 3
    )
    
    BuildingPlacementView(
        template: template,
        territoryId: "test-territory",
        territoryCoordinates: coords,
        existingBuildings: []
    )
}
