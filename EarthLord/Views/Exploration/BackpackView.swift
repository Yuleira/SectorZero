//
//  BackpackView.swift
//  EarthLord
//
//  背包页面 - 显示收集的物品
//

import SwiftUI

/// 背包视图
struct BackpackView: View {

    // MARK: - 状态

    @ObservedObject private var inventoryManager = InventoryManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory? = nil

    // MARK: - 计算属性

    /// 背包物品列表
    private var items: [CollectedItem] {
        inventoryManager.items
    }

    /// 过滤后的物品列表
    private var filteredItems: [CollectedItem] {
        var result = items

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.definition.category == category }
        }

        // 按搜索关键词筛选
        if !searchText.isEmpty {
            result = result.filter {
                $0.definition.name.localizedCaseInsensitiveContains(searchText) ||
                $0.definition.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// 是否显示空状态
    private var showEmptyState: Bool {
        items.isEmpty
    }

    /// 是否显示搜索无结果状态
    private var showNoSearchResults: Bool {
        !items.isEmpty && filteredItems.isEmpty
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜索栏和筛选器
                if !items.isEmpty {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    categoryFilter
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                // 内容区域
                contentView
            }
        }
        .navigationTitle(NSLocalizedString("背包", comment: "Backpack navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBackpackItems()
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField(NSLocalizedString("搜索物品...", comment: "Search items placeholder"), text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 分类筛选器

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部按钮
                categoryButton(category: nil, title: NSLocalizedString("全部", comment: "All categories"))

                // 各分类按钮
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    categoryButton(category: category, title: category.displayName)
                }
            }
        }
    }

    private func categoryButton(category: ItemCategory?, title: String) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelectedCategory(category) ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelectedCategory(category) ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(20)
        }
    }

    private func isSelectedCategory(_ category: ItemCategory?) -> Bool {
        selectedCategory == category
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        if showEmptyState {
            emptyStateView
        } else if showNoSearchResults {
            noSearchResultsView
        } else {
            itemListView
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "bag.fill",
            title: NSLocalizedString("背包空空如也", comment: "Empty backpack title"),
            subtitle: NSLocalizedString("去探索收集物资吧", comment: "Empty backpack subtitle"),
            buttonTitle: nil,
            action: nil
        )
    }

    /// 搜索无结果视图
    private var noSearchResultsView: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: NSLocalizedString("没有找到相关物品", comment: "No search results title"),
            subtitle: NSLocalizedString("试试其他关键词或清除筛选条件", comment: "No search results subtitle"),
            buttonTitle: nil,
            action: nil
        )
    }

    /// 物品列表
    private var itemListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    ItemRowView(item: item)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 业务逻辑

    /// 加载背包物品
    private func loadBackpackItems() {
        Task {
            await inventoryManager.loadItems()
        }
    }
}

// MARK: - 物品行视图

struct ItemRowView: View {
    let item: CollectedItem

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标（带稀有度边框）
            ZStack {
                // 稀有度渐变背景
                LinearGradient(
                    colors: item.definition.rarity.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 48, height: 48)
                .cornerRadius(12)

                Image(systemName: item.definition.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.definition.rarity.color, lineWidth: 2)
            )

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(item.displayName))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    Text(item.definition.rarity.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(item.definition.rarity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.definition.rarity.color.opacity(0.2))
                        .cornerRadius(4)

                    // 品质标签
                    Text(item.quality.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(item.quality.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.quality.color.opacity(0.2))
                        .cornerRadius(4)
                }

                Text(item.definition.category.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 数量
            Text("×\(item.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        BackpackView()
    }
}
