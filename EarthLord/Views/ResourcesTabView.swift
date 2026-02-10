//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  资源模块主入口页面
//  包含背包、交易两个分段
//

import SwiftUI

/// 资源分段类型
enum ResourceSegment: Int, CaseIterable {
    case backpack = 0
    case trade

    var title: LocalizedStringKey {
        switch self {
        case .backpack:
            return "segment_backpack"
        case .trade:
            return "segment_trade"
        }
    }
}

/// 资源模块主入口页面
struct ResourcesTabView: View {

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .backpack

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
            .navigationTitle(LocalizedString.tabResources)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 分段选择器

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("resource_segment_picker", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 内容区域

    /// 根据选中分段显示对应内容
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .backpack:
            BackpackView()

        case .trade:
            TradeTabView()
        }
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
