//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件
//  显示建筑图标、名称、等级、成本预览
//

import SwiftUI

struct BuildingCard: View {
    let template: BuildingTemplate
    let isLocked: Bool
    let isDisabled: Bool
    let statusText: String?
    let countText: String?
    let onTap: () -> Void
    
    /// 资源成本摘要（显示前3个资源）
    private var resourceSummary: String {
        let resources = template.requiredResources.prefix(3)
        return resources.map { "\(InventoryManager.shared.resourceDisplayName(for: $0.key)) ×\($0.value)" }
            .joined(separator: ", ")
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部：图标 + 等级标签
                HStack {
                    // 建筑图标
                    ZStack {
                        Circle()
                            .fill(template.category.accentColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: template.icon)
                            .font(.system(size: 24))
                            .foregroundColor(isLocked ? ApocalypseTheme.textMuted : template.category.accentColor)
                    }
                    
                    Spacer()
                    
                    // 等级标签
                    Text(String(format: String(localized: "building_tier_format"), template.tier))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isLocked ? ApocalypseTheme.textMuted : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.cardBackground)
                        )
                }
                
                // 建筑名称
                    Text(template.localizedName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isLocked ? ApocalypseTheme.textMuted : ApocalypseTheme.textPrimary)
                    .lineLimit(1)
                
                // 描述
                Text(template.localizedDescription)
                    .font(.system(size: 12))
                    .foregroundColor(isLocked ? ApocalypseTheme.textMuted : ApocalypseTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
            // 构建计数
            if let countText {
                Text(countText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 资源成本摘要
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    
                    Text(resourceSummary)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .lineLimit(1)
                }
                
                // 底部：建造时间 + 上限
                HStack {
                    // 建造时间
                    Label {
                        Text("\(template.buildTimeSeconds)s")
                            .font(.system(size: 11, weight: .medium))
                    } icon: {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    
                    Spacer()
                    
                    // 领地上限
                    Label {
                        Text(String(format: String(localized: "building_max_limit_format"), template.maxPerTerritory))
                            .font(.system(size: 11, weight: .medium))
                    } icon: {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isLocked ? ApocalypseTheme.textMuted.opacity(0.2) : template.category.accentColor.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .opacity((isLocked || isDisabled) ? 0.6 : 1.0)
            .overlay(
                // 锁定遮罩
                Group {
                    if isLocked {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.4))
                            
                            VStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                
                                Text(String(localized: "common_locked"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            )
            if let statusText {
                HStack {
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isDisabled ? ApocalypseTheme.danger : ApocalypseTheme.success)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Preview

#Preview {
    let sampleTemplate = BuildingTemplate(
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
    
    VStack(spacing: 16) {
        BuildingCard(
            template: sampleTemplate,
            isLocked: false,
            isDisabled: false,
            statusText: nil,
            countText: nil,
            onTap: {}
        )
        
        BuildingCard(
            template: sampleTemplate,
            isLocked: true,
            isDisabled: true,
            statusText: String(localized: "common_locked"),
            countText: nil,
            onTap: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
