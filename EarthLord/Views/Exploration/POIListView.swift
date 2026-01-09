//
//  POIListView.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  附近兴趣点列表页面
//  显示玩家周围可探索的地点
//

import SwiftUI
import CoreLocation

/// 附近兴趣点列表页面
struct POIListView: View {

    // MARK: - 状态

    /// 当前选中的分类筛选
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching = false

    /// POI 列表数据
    @State private var pois: [ExplorationPOI] = MockExplorationData.pois

    /// 模拟 GPS 坐标
    private let mockCoordinate = CLLocationCoordinate2D(latitude: 22.54, longitude: 114.06)

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [ExplorationPOI] {
        if let category = selectedCategory {
            return pois.filter { $0.type == category }
        }
        return pois
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        pois.filter { $0.status != .undiscovered }.count
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar
                    .padding(.bottom, 8)

                // POI 列表
                poiList
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    /// 顶部状态栏：显示 GPS 坐标和发现数量
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(String(format: "%.2f, %.2f", mockCoordinate.latitude, mockCoordinate.longitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    /// 搜索附近 POI 按钮
    private var searchButton: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isSearching ? "搜索中..." : "搜索附近POI")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
        }
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    /// 横向滚动的分类筛选按钮
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部按钮
                filterButton(title: "全部", type: nil)

                // 各分类按钮
                filterButton(title: "医院", type: .hospital)
                filterButton(title: "超市", type: .supermarket)
                filterButton(title: "工厂", type: .factory)
                filterButton(title: "药店", type: .pharmacy)
                filterButton(title: "加油站", type: .gasStation)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 单个筛选按钮
    private func filterButton(title: String, type: POIType?) -> some View {
        let isSelected = selectedCategory == type

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = type
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - POI 列表

    /// POI 列表视图
    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredPOIs.isEmpty {
                    emptyView
                } else {
                    ForEach(filteredPOIs) { poi in
                        poiCard(poi)
                            .onTapGesture {
                                handlePOITap(poi)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // 避开 TabBar
        }
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到符合条件的地点")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// 单个 POI 卡片
    private func poiCard(_ poi: ExplorationPOI) -> some View {
        HStack(spacing: 12) {
            // 类型图标
            poiIcon(for: poi.type)

            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型文字
                Text(poi.type.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 状态标签
            VStack(alignment: .trailing, spacing: 4) {
                // 发现状态
                statusBadge(for: poi.status)

                // 物资状态（如果有）
                if poi.status == .hasLoot {
                    lootBadge
                }
            }

            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// POI 类型图标
    private func poiIcon(for type: POIType) -> some View {
        let (icon, color) = iconAndColor(for: type)

        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
        }
    }

    /// 根据 POI 类型返回图标和颜色
    private func iconAndColor(for type: POIType) -> (String, Color) {
        switch type {
        case .hospital:
            return ("cross.case.fill", .red)
        case .supermarket:
            return ("cart.fill", .green)
        case .factory:
            return ("building.2.fill", .gray)
        case .pharmacy:
            return ("pills.fill", .purple)
        case .gasStation:
            return ("fuelpump.fill", .orange)
        case .warehouse:
            return ("shippingbox.fill", .brown)
        case .residence:
            return ("house.fill", .blue)
        case .office:
            return ("building.fill", .cyan)
        case .school:
            return ("book.fill", .yellow)
        case .police:
            return ("shield.fill", .indigo)
        }
    }

    /// 发现状态标签
    private func statusBadge(for status: POIStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .undiscovered:
                return ("未发现", ApocalypseTheme.textMuted)
            case .discovered:
                return ("已发现", ApocalypseTheme.info)
            case .hasLoot:
                return ("已发现", ApocalypseTheme.info)
            case .looted:
                return ("已搜空", ApocalypseTheme.textSecondary)
            case .dangerous:
                return ("危险", ApocalypseTheme.danger)
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    /// 物资可用标签
    private var lootBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 9))

            Text("有物资")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(ApocalypseTheme.success)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(ApocalypseTheme.success.opacity(0.15))
        )
    }

    // MARK: - 方法

    /// 执行搜索
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以刷新 POI 数据
            print("搜索完成，刷新 POI 列表")
        }
    }

    /// 处理 POI 点击
    private func handlePOITap(_ poi: ExplorationPOI) {
        print("点击了 POI: \(poi.name) (\(poi.id))")
        // TODO: 跳转到详情页
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIListView()
    }
}
