//
//  TerritoryTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//
//  领地管理页面
//  显示我的领地列表、统计信息、支持查看详情和删除

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 状态属性

    /// 领地管理器
    @ObservedObject private var territoryManager = TerritoryManager.shared

    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 选中的领地（用于 sheet）
    @State private var selectedTerritory: Territory?

    /// 是否正在加载
    @State private var isLoading = false

    /// 错误信息
    @State private var errorMessage: String?

    // MARK: - 计算属性

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if !authManager.isAuthenticated {
                    // 未登录状态
                    notLoggedInView
                } else if isLoading && myTerritories.isEmpty {
                    // 加载中（首次加载）
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地".localized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadTerritories()
            }
            .onAppear {
                Task {
                    await loadTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        // 删除后刷新列表
                        Task {
                            await loadTerritories()
                        }
                    }
                )
            }
        }
    }

    // MARK: - 子视图

    /// 未登录视图
    private var notLoggedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("请先登录")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("登录后即可查看和管理你的领地")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 统计信息卡片
                statsCard
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 领地卡片列表
                ForEach(myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                        .padding(.horizontal)
                }

                // 底部间距（避开 TabBar）
                Spacer()
                    .frame(height: 100)
            }
        }
    }

    /// 统计信息卡片
    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地数量")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(width: 1, height: 40)

            // 总面积
            VStack(spacing: 4) {
                Text(formattedTotalArea)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.success)

                Text("总面积")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 方法

    /// 加载领地列表
    private func loadTerritories() async {
        guard authManager.isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("🏴 [领地页面] 加载失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 领地卡片组件

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // 面积
                    Label(territory.formattedArea, systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 点数
                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 点", systemImage: "mappin.circle")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 时间
                if let time = territory.formattedCompletedAt {
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

#Preview {
    TerritoryTabView()
}
