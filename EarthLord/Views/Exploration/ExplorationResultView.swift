//
//  ExplorationResultView.swift
//  EarthLord
//
//  Created by Claude on 09/01/2026.
//
//  探索结果弹窗页面
//  显示探索完成后的统计数据和获得的物品
//

import SwiftUI

/// 探索结果弹窗页面
struct ExplorationResultView: View {

    // MARK: - 参数

    /// 探索结果
    let result: ExplorationResult

    /// 玩家累计统计（用于显示累计数据和排名）
    let stats: ExplorationStats

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    /// 动画状态
    @State private var showContent = false
    @State private var showItems = false

    /// 数字动画进度 (0-1)
    @State private var numberAnimationProgress: Double = 0

    /// 对勾弹跳动画
    @State private var checkmarkScale: [Bool] = []

    // MARK: - 计算属性

    /// 探索时长（秒）
    private var duration: TimeInterval {
        result.endTime.timeIntervalSince(result.startTime)
    }

    /// 格式化时长
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d分%02d秒", minutes, seconds)
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 成就标题
                    achievementHeader
                        .padding(.top, 40)

                    // 统计数据卡片
                    statsCard
                        .padding(.horizontal, 20)

                    // 奖励物品卡片
                    rewardsCard
                        .padding(.horizontal, 20)

                    // 确认按钮
                    confirmButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // 初始化对勾动画状态
            checkmarkScale = Array(repeating: false, count: result.itemsCollected.count)

            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }

            // 数字跳动动画
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                numberAnimationProgress = 1.0
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                showItems = true
            }

            // 对勾弹跳动画（每个间隔0.2秒）
            for index in 0..<result.itemsCollected.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(index) * 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        if index < checkmarkScale.count {
                            checkmarkScale[index] = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 成就标题

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标容器
            ZStack {
                // 光晕效果
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1 : 0.5)

                // 图标背景
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 100, height: 100)

                // 地图图标
                Image(systemName: "map.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
                    .scaleEffect(showContent ? 1 : 0.3)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("你的足迹又扩展了一点")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
        }
    }

    // MARK: - 统计数据卡片

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            // 统计数据行
            VStack(spacing: 12) {
                // 行走距离
                statRow(
                    icon: "figure.walk",
                    title: "行走距离",
                    thisTime: formatDistance(result.distanceWalked),
                    total: formatDistance(stats.totalDistance),
                    rank: stats.distanceRank,
                    value: result.distanceWalked
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索面积
                statRow(
                    icon: "square.dashed",
                    title: "探索面积",
                    thisTime: formatArea(result.areaExplored),
                    total: formatArea(stats.totalArea),
                    rank: stats.areaRank,
                    value: result.areaExplored
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索时长
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(width: 24)

                    Text("探索时长")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    Text(formattedDuration)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
    }

    /// 单行统计数据
    private func statRow(icon: String, title: String, thisTime: String, total: String, rank: Int, value: Double) -> some View {
        VStack(spacing: 8) {
            // 第一行：图标 + 标题 + 本次数据（带数字动画）
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 数字动画：从0增长到目标值
                Text(formatAnimatedValue(value * numberAnimationProgress, isDistance: icon == "figure.walk"))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            // 第二行：累计 + 排名
            HStack {
                Spacer()
                    .frame(width: 24)

                Text("累计 \(total)")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Spacer()

                // 排名（带缩放动画）
                HStack(spacing: 2) {
                    Text("#")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(Int(Double(rank) * numberAnimationProgress))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(numberAnimationProgress > 0.9 ? 1.0 : 0.8)
            }
        }
    }

    /// 格式化动画数值
    private func formatAnimatedValue(_ value: Double, isDistance: Bool) -> String {
        if isDistance {
            return formatDistance(value)
        } else {
            return formatArea(value)
        }
    }

    // MARK: - 奖励物品卡片

    /// 奖励物品卡片
    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(result.itemsCollected.count) 件")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 物品列表
            VStack(spacing: 10) {
                ForEach(Array(result.itemsCollected.enumerated()), id: \.element.id) { index, item in
                    if let definition = MockExplorationData.getItemDefinition(by: item.itemId) {
                        rewardItemRow(item: item, definition: definition, index: index)
                    }
                }
            }

            // 底部提示
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 11))

                Text("已添加到背包")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.success)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .opacity(showItems ? 1 : 0)
        .offset(y: showItems ? 0 : 30)
    }

    /// 单个奖励物品行
    private func rewardItemRow(item: CollectedItem, definition: ItemDefinition, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(for: definition.category).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: definition.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(categoryColor(for: definition.category))
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = item.quality {
                    Text(quality.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(qualityColor(for: quality))
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(index < checkmarkScale.count && checkmarkScale[index] ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: checkmarkScale)
        }
        .padding(.vertical, 4)
        .opacity(showItems ? 1 : 0)
        .offset(x: showItems ? 0 : 20)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.2), value: showItems)
    }

    // MARK: - 确认按钮

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))

                Text("确认")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ApocalypseTheme.primary)
            )
        }
        .opacity(showItems ? 1 : 0)
    }

    // MARK: - 辅助方法

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积
    private func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 10000 {
            return String(format: "%.2f 公顷", squareMeters / 10000)
        } else {
            return String(format: "%.0f m²", squareMeters)
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

    /// 品质颜色
    private func qualityColor(for quality: ItemQuality) -> Color {
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
    }
}

// MARK: - 预览

#Preview {
    ExplorationResultView(
        result: MockExplorationData.sampleExplorationResult,
        stats: MockExplorationData.sampleExplorationStats
    )
}
