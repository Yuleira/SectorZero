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
            .navigationTitle(LocalizedString.territoryMyTitle)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadTerritories()
            }
            .onAppear {
                Task {
                    await loadTerritories()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                // 监听领地更新通知，刷新列表
                Task {
                    await loadTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        Task {
                            await loadTerritories()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - 子视图

    /// 未登录视图
    private var notLoggedInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 12) {
                Text(LocalizedString.authLoginRequired)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(LocalizedString.territoryLoginPrompt)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 登录按钮
            Button {
                debugLog("🏴 [TerritoryTabView] Go to Login button tapped")
                // 强制触发认证状态检查和重置
                // 这会确保 ContentView 正确切换到 AuthView
                Task { @MainActor in
                    debugLog("🏴 [TerritoryTabView] Calling forceSignOut()")
                    // 重置认证状态，强制显示登录界面
                    authManager.forceSignOut()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(LocalizedString.authGoToLogin)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                )
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text(LocalizedString.commonLoading)
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

            Text(LocalizedString.territoryEmptyTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(LocalizedString.territoryEmptyDescription)
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

    /// 统计信息卡片 — Tactical Aurora Glassmorphism
    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.orange)

                Text(LocalizedString.territoryCountLabel)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // 分隔线 — 霓虹绿
            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 1, height: 40)

            // 总面积
            VStack(spacing: 4) {
                Text(formattedTotalArea)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.orange)

                Text(LocalizedString.territoryTotalAreaLabel)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
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
            debugLog("🏴 [领地页面] 加载失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 领地卡片组件

struct TerritoryCard: View {
    let territory: Territory

    /// 辉光脉冲动画
    @State private var isGlowing = false

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标 — 放大 + 辉光脉冲
            ZStack {
                // 外层辉光环
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.orange.opacity(isGlowing ? 0.5 : 0.1), radius: isGlowing ? 10 : 4)

                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "flag.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.orange)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // 面积 — Monospaced terminal
                    Label {
                        Text(territory.formattedArea)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    } icon: {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    // 点数 — Monospaced terminal
                    if let pointCount = territory.pointCount {
                        Label {
                            Text(String(format: String(localized: LocalizedString.territoryPointsFormat), pointCount))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        } icon: {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 距离 — Monospaced terminal
                    if let dist = territory.distanceWalked, dist > 0 {
                        Label {
                            Text(territory.formattedDistance)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        } icon: {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 时间
                if let time = territory.formattedCompletedAt {
                    Text(time)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 右侧箭头 — 霓虹绿
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.orange.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

#Preview {
    TerritoryTabView()
}
