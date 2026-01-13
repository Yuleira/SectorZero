//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示视图
//  显示从POI搜刮获得的物品
//

import SwiftUI
import CoreLocation

/// 搜刮结果视图
struct ScavengeResultView: View {

    // MARK: - 属性

    /// 搜刮结果
    let result: ScavengeResult

    /// 关闭回调
    let onDismiss: () -> Void

    // MARK: - 状态

    @State private var showItems = false

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 结果卡片
            VStack(spacing: 0) {
                // 顶部成功标志
                successHeader

                // 物品列表
                itemsList

                // 确认按钮
                confirmButton
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ApocalypseTheme.background)
            )
            .padding(.horizontal, 24)
            .onAppear {
                // 延迟显示物品动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showItems = true
                    }
                }
            }
        }
    }

    // MARK: - 子视图

    /// 成功头部
    private var successHeader: some View {
        VStack(spacing: 12) {
            // 成功图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }

            // 标题
            Text("搜刮成功！")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // POI信息
            HStack(spacing: 6) {
                Image(systemName: result.poi.type.icon)
                    .font(.system(size: 14))
                Text(result.poi.name)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    /// 物品列表
    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("获得物品")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(result.items.count) 种")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 20)

            // 物品卡片
            VStack(spacing: 8) {
                ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                    if showItems {
                        itemRow(item: item)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    /// 物品行
    private func itemRow(item: CollectedItem) -> some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.definition.rarity.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: item.definition.icon)
                    .font(.system(size: 20))
                    .foregroundColor(item.definition.rarity.color)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    if item.definition.rarity != .common {
                        Text(item.definition.rarity.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(item.definition.rarity.color)
                            )
                    }
                }

                // 品质和分类
                HStack(spacing: 8) {
                    Text(item.quality.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(item.quality.color)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(item.definition.category.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                Text("确认")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ApocalypseTheme.primary)
            )
        }
        .padding(20)
    }
}

// MARK: - 预览

#Preview {
    ScavengeResultView(
        result: ScavengeResult(
            poi: NearbyPOI(
                id: "test",
                name: "全家便利店",
                type: .convenience,
                coordinate: .init(latitude: 0, longitude: 0)
            ),
            items: [
                CollectedItem(
                    definition: ItemDefinition(
                        id: "water",
                        name: "纯净水",
                        description: "干净的水",
                        category: .water,
                        icon: "drop.fill",
                        rarity: .common
                    ),
                    quality: .good,
                    quantity: 2
                ),
                CollectedItem(
                    definition: ItemDefinition(
                        id: "bandage",
                        name: "急救包",
                        description: "医疗用品",
                        category: .medical,
                        icon: "cross.case.fill",
                        rarity: .rare
                    ),
                    quality: .worn,
                    quantity: 1
                )
            ]
        ),
        onDismiss: {}
    )
}
