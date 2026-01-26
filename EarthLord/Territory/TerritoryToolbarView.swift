//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  领地工具栏（浮动顶部）
//  提供返回、建造、信息按钮
//

import SwiftUI

struct TerritoryToolbarView: View {
    let territoryName: LocalizedStringResource
    let onBack: () -> Void
    let onBuild: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack {
            // 返回按钮
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text(LocalizedString.commonBack)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            }

            Spacer()

            // 领地名称（中央）- 接收 LocalizedStringResource 实现 Late-Binding
            Text(territoryName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            
            Spacer()
            
            // 建造按钮
            Button(action: onBuild) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                    Text(LocalizedString.startBuilding)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 4, x: 0, y: 2)
                )
            }
            
            // 信息按钮
            Button(action: onInfo) {
                Image(systemName: "gear")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                territoryName: LocalizedString.unnamedTerritory,
                onBack: {},
                onBuild: {},
                onInfo: {}
            )
            
            Spacer()
        }
    }
}
