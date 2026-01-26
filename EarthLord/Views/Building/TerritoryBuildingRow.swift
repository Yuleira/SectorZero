//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件
//  显示建筑状态、进度环、倒计时和操作菜单
//

import SwiftUI

struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    let onUpgrade: () -> Void
    let onDemolish: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：建筑图标 + 进度环
            buildingIcon
            
            // 中间：建筑信息
            VStack(alignment: .leading, spacing: 4) {
                // 建筑名称 (LocalizedStringResource 或 fallback)
                Group {
                    if let t = template {
                        Text(t.localizedName)
                    } else {
                        Text(building.buildingName)
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                
                // 状态或倒计时
                if building.status == .constructing {
                    HStack(spacing: 4) {
                        Text(building.status.localizedName)
                            .font(.system(size: 13))
                            .foregroundColor(building.status.accentColor)
                        
                        Text("•")
                            .foregroundColor(ApocalypseTheme.textMuted)
                        
                        Text(building.formattedRemainingTime)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.info)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(building.status.localizedName)
                            .font(.system(size: 13))
                            .foregroundColor(building.status.accentColor)
                        
                        Text("•")
                            .foregroundColor(ApocalypseTheme.textMuted)
                        
                        Text(String(format: String(localized: "building_level_format %lld", locale: LanguageManager.shared.currentLocale), building.level))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // 右侧：操作菜单（仅激活状态）
            if building.status == .active {
                Menu {
                    // 升级选项
                    if let template = template, building.level < template.maxLevel {
                        Button {
                            onUpgrade()
                        } label: {
                            Label("building_upgrade", systemImage: "arrow.up.circle")
                        }
                    }
                    
                    // 拆除选项
                    Button(role: .destructive) {
                        onDemolish()
                    } label: {
                        Label("building_demolish", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
    
    // MARK: - Subviews
    
    /// 建筑图标（带进度环）
    private var buildingIcon: some View {
        ZStack {
            // 背景圆
            Circle()
                .fill(template?.category.accentColor.opacity(0.2) ?? Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            // 进度环（仅建造中时显示）
            if building.status == .constructing {
                Circle()
                    .trim(from: 0, to: building.buildProgress)
                    .stroke(
                        template?.category.accentColor ?? ApocalypseTheme.info,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
            }
            
            // 图标
            Image(systemName: template?.icon ?? "building.2")
                .font(.system(size: 22))
                .foregroundColor(template?.category.accentColor ?? ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        // 建造中
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "campfire",
                buildingName: "Campfire",
                status: .constructing,
                level: 1,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date(),
                buildCompletedAt: Date().addingTimeInterval(45)
            ),
            template: BuildingTemplate(
                id: UUID(),
                templateId: "campfire",
                name: "building_name_campfire",
                category: .survival,
                tier: 1,
                description: "building_description_campfire",
                icon: "flame.fill",
                requiredResources: ["wood": 30],
                buildTimeSeconds: 60,
                maxPerTerritory: 3,
                maxLevel: 3
            ),
            onUpgrade: {},
            onDemolish: {}
        )
        
        // 已激活
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "shelter_frame",
                buildingName: "Shelter Frame",
                status: .active,
                level: 2,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date().addingTimeInterval(-3600),
                buildCompletedAt: Date().addingTimeInterval(-3300)
            ),
            template: BuildingTemplate(
                id: UUID(),
                templateId: "shelter_frame",
                name: "building_name_shelter_frame",
                category: .survival,
                tier: 2,
                description: "building_description_shelter_frame",
                icon: "tent.fill",
                requiredResources: ["wood": 60],
                buildTimeSeconds: 180,
                maxPerTerritory: 2,
                maxLevel: 5
            ),
            onUpgrade: {},
            onDemolish: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
