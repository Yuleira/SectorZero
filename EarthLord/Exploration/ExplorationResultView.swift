//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面 - 显示探索成功或失败的结果
//

import SwiftUI

/// 探索结果视图
struct ExplorationResultView: View {

    // MARK: - 属性

    let result: ExplorationResult
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if result.isSuccess {
                successView
            } else {
                errorView
            }
        }
    }

    // MARK: - 成功视图

    private var successView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 奖励等级徽章
                rewardTierBadge
                    .padding(.top, 20)

                // 统计信息
                statsSection

                // 收集的物品
                if !result.itemsCollected.isEmpty {
                    collectedItemsSection
                }

                // 存储满警告
                if result.storageWarning {
                    storageWarningBanner
                }

                // 经验值
                experienceSection

                // 关闭按钮
                Button(action: onDismiss) {
                    Text(LocalizedString.commonDone)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
            }
            .padding(20)
        }
    }

    // MARK: - 奖励等级徽章

    private var rewardTierBadge: some View {
        let tier = RewardTier.from(distance: result.distanceWalked)

        return VStack(spacing: 16) {
            // 等级徽章圆形
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tier.color, tier.color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: tier.color.opacity(0.5), radius: 10)

                Image(systemName: tier.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }

            // 等级名称
            Text(tier.localizedName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(tier.color)

            // 成功消息
            Text(result.message)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 行走距离
            Text(String(format: String(localized: LocalizedString.explorationWalkedFormat), String(format: "%.0f", result.distanceWalked)))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    // MARK: - 错误视图

    private var errorView: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle.fill",
            title: "exploration_failed",
            subtitle: LocalizedStringKey(result.message),
            buttonTitle: onRetry != nil ? "common_retry" : nil,
            action: onRetry
        )
        .overlay(alignment: .topTrailing) {
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(20)
        }
    }

    // MARK: - 统计信息区域

    private var statsSection: some View {
        VStack(spacing: 16) {
            Text(LocalizedString.explorationStats)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                statRow(
                    icon: "figure.walk",
                    label: LocalizedString.explorationDistance,
                    value: String(format: String(localized: LocalizedString.explorationDistanceValue), String(format: "%.1f", result.distanceWalked))
                )
                statRow(
                    icon: "clock.fill",
                    label: LocalizedString.explorationDuration,
                    value: result.stats.durationString
                )
                statRow(
                    icon: "mappin.circle.fill",
                    label: LocalizedString.explorationPointsVerified,
                    value: String(format: String(localized: LocalizedString.explorationPointsCount), result.stats.pointsVerified)
                )
                statRow(
                    icon: "chart.bar.fill",
                    label: LocalizedString.explorationDistanceRank,
                    value: result.stats.distanceRank
                )
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    private func statRow(icon: String, label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    /// 存储满警告条
    private var storageWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.warning)
            Text(LocalizedString.resultStorageFullWarning)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.warning)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.warning.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - 收集物品区域

    private var collectedItemsSection: some View {
        VStack(spacing: 16) {
            Text(LocalizedString.explorationCollectedItems)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(result.itemsCollected) { item in
                    ItemRowView(item: item)
                }
            }
        }
    }

    // MARK: - 经验值区域

    private var experienceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            Text(LocalizedString.explorationExperienceGained)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text("+\(result.experienceGained) EXP")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview("成功") {
    ExplorationResultView(
        result: MockExplorationData.sampleExplorationResult,
        onDismiss: {},
        onRetry: nil
    )
}

#Preview("失败") {
    ExplorationResultView(
        result: ExplorationResult(
            isSuccess: false,
            message: "探索失败，请检查GPS信号",
            itemsCollected: [],
            experienceGained: 0,
            distanceWalked: 0,
            stats: ExplorationStats(
                totalDistance: 0,
                duration: 0,
                pointsVerified: 0,
                distanceRank: "F"
            ),
            startTime: Date(),
            endTime: Date()
        ),
        onDismiss: {},
        onRetry: {
            debugLog("重试探索")
        }
    )
}
