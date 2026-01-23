//
//  ResourceRow.swift
//  EarthLord
//
//  可复用的资源成本行组件
//  显示资源图标、名称、需求数量和拥有数量
//

import SwiftUI

struct ResourceRow: View {
    let resourceId: String
    let requiredAmount: Int
    let availableAmount: Int
    
    /// 是否有足够的资源
    private var isSufficient: Bool {
        availableAmount >= requiredAmount
    }
    
    /// 资源图标（基于 ItemDefinition 或内置映射）
    private var resourceIcon: String {
        InventoryManager.shared.resourceIconName(for: resourceId)
    }
    
    /// 资源显示名称（本地化）
    private var resourceName: String {
        InventoryManager.shared.resourceDisplayName(for: resourceId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.system(size: 20))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .frame(width: 24, height: 24)
            
            // 资源名称
            Text(resourceName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
            
            Spacer()
            
            // 数量对比
            HStack(spacing: 4) {
                // 拥有数量
                Text("\(availableAmount)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                
                // 分隔符
                Text("/")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textMuted)
                
                // 需求数量
                Text("\(requiredAmount)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ApocalypseTheme.cardBackground.opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ResourceRow(
            resourceId: "wood",
            requiredAmount: 30,
            availableAmount: 45
        )
        
        ResourceRow(
            resourceId: "stone",
            requiredAmount: 20,
            availableAmount: 15
        )
        
        ResourceRow(
            resourceId: "metal",
            requiredAmount: 10,
            availableAmount: 10
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
