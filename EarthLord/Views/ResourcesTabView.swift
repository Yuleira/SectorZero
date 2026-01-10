//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易五个分段
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0
    case backpack
    case purchased
    case territory
    case trade

    var title: String {
        switch self {
        case .poi:
            return "POI"
        case .backpack:
            return "背包".localized
        case .purchased:
            return "已购".localized
        case .territory:
            return "领地".localized
        case .trade:
            return "交易".localized
        }
    }
}

/// 资源模块主入口页面
struct ResourcesTabView: View {

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("资源分段".localized, selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 交易开关

    /// 交易开关
    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易".localized)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .tint(ApocalypseTheme.primary)
        }
    }

    // MARK: - 内容区域

    /// 根据选中分段显示对应内容
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            placeholderView(title: "POI列表".localized, icon: "mappin.circle.fill")

        case .backpack:
            placeholderView(title: "背包".localized, icon: "bag.fill")

        case .purchased:
            placeholderView(title: "已购".localized, icon: "cart.fill")

        case .territory:
            placeholderView(title: "领地资源".localized, icon: "flag.fill")

        case .trade:
            placeholderView(title: "交易市场".localized, icon: "arrow.left.arrow.right")
        }
    }

    /// 占位视图
    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("功能开发中".localized)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
