//
//  BackpackView.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  背包管理页面
//  显示玩家拥有的物品，支持搜索、筛选和管理
//

import SwiftUI

/// 背包管理页面
struct BackpackView: View {

    // MARK: - 状态

    /// 搜索关键词
    @State private var searchText = ""

    /// 当前选中的分类
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包物品列表
    @State private var items: [InventoryItem] = MockExplorationData.inventoryItems

    /// 动画用的容量百分比
    @State private var animatedCapacityPercentage: Double = 0

    // MARK: - 常量

    /// 背包最大容量
    private let maxCapacity: Double = 100

    // MARK: - 计算属性

    /// 当前使用容量
    private var usedCapacity: Double {
        MockExplorationData.calculateTotalWeight(items: items)
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    /// 进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        var result = items

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                    return definition.category == category
                }
                return false
            }
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                    return definition.name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        return result
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 分类筛选
                categoryFilter
                    .padding(.top, 12)

                // 物品列表
                itemList
                    .padding(.top, 8)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 容量进度条动画
            withAnimation(.easeOut(duration: 0.8)) {
                animatedCapacityPercentage = capacityPercentage
            }
        }
    }

    // MARK: - 容量状态卡

    /// 背包容量状态卡
    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 容量数值
                Text(String(format: "%.1f / %.0f kg", usedCapacity, maxCapacity))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 8)

                    // 进度（带动画）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * min(animatedCapacityPercentage, 1.0), height: 8)
                        .animation(.easeOut(duration: 0.5), value: animatedCapacityPercentage)
                }
            }
            .frame(height: 8)

            // 警告提示（容量超过90%时显示）
            if capacityPercentage > 0.9 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))

                    Text("背包快满了！")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 搜索框

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 分类筛选

    /// 分类筛选按钮
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部
                categoryButton(title: "全部", icon: "square.grid.2x2.fill", category: nil)

                // 食物
                categoryButton(title: "食物", icon: "fork.knife", category: .food)

                // 水
                categoryButton(title: "水", icon: "drop.fill", category: .water)

                // 材料
                categoryButton(title: "材料", icon: "cube.fill", category: .material)

                // 工具
                categoryButton(title: "工具", icon: "wrench.fill", category: .tool)

                // 医疗
                categoryButton(title: "医疗", icon: "cross.case.fill", category: .medical)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 单个分类按钮
    private func categoryButton(title: String, icon: String, category: ItemCategory?) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 物品列表

    /// 物品列表
    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if filteredItems.isEmpty {
                    emptyView
                        .transition(.opacity)
                } else {
                    ForEach(filteredItems) { item in
                        if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                            itemCard(item: item, definition: definition)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // 避开 TabBar
            .animation(.easeInOut(duration: 0.3), value: selectedCategory)
        }
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            if !searchText.isEmpty || selectedCategory != nil {
                Text("尝试清除筛选条件")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// 单个物品卡片
    private func itemCard(item: InventoryItem, definition: ItemDefinition) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            itemIcon(definition: definition)

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：名称 + 稀有度标签
                HStack(spacing: 6) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    rarityBadge(rarity: definition.rarity)
                }

                // 第二行：数量 + 重量 + 品质
                HStack(spacing: 8) {
                    // 数量
                    Text("x\(item.quantity)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 重量
                    Text(String(format: "%.1fkg", definition.weight * Double(item.quantity)))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        qualityBadge(quality: quality)
                    }
                }
            }

            Spacer()

            // 操作按钮
            VStack(spacing: 6) {
                actionButton(title: "使用", color: ApocalypseTheme.info) {
                    handleUse(item: item, definition: definition)
                }

                actionButton(title: "存储", color: ApocalypseTheme.textMuted) {
                    handleStore(item: item, definition: definition)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 物品图标
    private func itemIcon(definition: ItemDefinition) -> some View {
        let color = categoryColor(for: definition.category)

        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: definition.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
        }
    }

    /// 分类颜色
    private func categoryColor(for category: ItemCategory) -> Color {
        switch category {
        case .water:
            return .blue
        case .food:
            return .green
        case .medical:
            return .red
        case .material:
            return .brown
        case .tool:
            return .orange
        case .weapon:
            return .purple
        case .other:
            return .gray
        }
    }

    /// 稀有度标签
    private func rarityBadge(rarity: ItemRarity) -> some View {
        let color: Color = {
            switch rarity {
            case .common:
                return .gray
            case .uncommon:
                return .green
            case .rare:
                return .blue
            case .epic:
                return .purple
            case .legendary:
                return .orange
            }
        }()

        return Text(rarity.rawValue)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    /// 品质标签
    private func qualityBadge(quality: ItemQuality) -> some View {
        let color: Color = {
            switch quality {
            case .pristine:
                return .green
            case .good:
                return .blue
            case .worn:
                return .yellow
            case .damaged:
                return .orange
            case .ruined:
                return .red
            }
        }()

        return Text(quality.rawValue)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
    }

    /// 操作按钮
    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
    }

    // MARK: - 操作方法

    /// 使用物品
    private func handleUse(item: InventoryItem, definition: ItemDefinition) {
        print("使用物品: \(definition.name) (id: \(item.id))")
        // TODO: 实现使用逻辑
    }

    /// 存储物品
    private func handleStore(item: InventoryItem, definition: ItemDefinition) {
        print("存储物品: \(definition.name) (id: \(item.id))")
        // TODO: 实现存储逻辑
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        BackpackView()
    }
}
