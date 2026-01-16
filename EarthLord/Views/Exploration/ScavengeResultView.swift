//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果展示视图
//  显示从POI搜刮获得的物品（支持 AI 生成物品展示）
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
    @State private var expandedItemId: UUID? = nil

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
            Text(NSLocalizedString("搜刮成功！", comment: "Scavenge success title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // POI信息
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: result.poi.type.icon)
                        .font(.system(size: 14))
                    Text(result.poi.name)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)

                // 危险等级标签
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(String(format: NSLocalizedString("危险等级 %d", comment: "Danger level"), result.poi.dangerLevel))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(dangerLevelColor)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch result.poi.dangerLevel {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    /// 物品列表
    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text(NSLocalizedString("获得物品", comment: "Items obtained"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 显示 AI 生成标识
                if result.items.first?.isAIGenerated == true {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text(NSLocalizedString("AI 生成", comment: "AI Generated badge"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.purple)
                }

                Text(String(format: NSLocalizedString("%d 种", comment: "Item count"), result.items.count))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 20)

            // 物品卡片
            ScrollView {
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
            .frame(maxHeight: 300)
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    /// 物品行
    private func itemRow(item: CollectedItem) -> some View {
        let isExpanded = expandedItemId == item.id

        return VStack(spacing: 0) {
            // 主要物品信息
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
                        // 使用 displayName（优先 AI 名称）并支持本地化
                        Text(LocalizedStringKey(item.displayName))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        // 稀有度标签
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

                    // 品质和分类
                    HStack(spacing: 8) {
                        Text(item.quality.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(item.quality.color)

                        Text("·")
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(item.definition.category.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        // 如果有故事，显示展开提示
                        if item.aiStory != nil {
                            Text("·")
                                .foregroundColor(ApocalypseTheme.textMuted)

                            HStack(spacing: 2) {
                                Image(systemName: isExpanded ? "chevron.up" : "text.quote")
                                    .font(.system(size: 10))
                                Text(isExpanded ? NSLocalizedString("收起", comment: "Collapse") : NSLocalizedString("故事", comment: "Story"))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.purple.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                if item.aiStory != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedItemId = isExpanded ? nil : item.id
                    }
                }
            }

            // 展开的故事区域
            if isExpanded, let story = item.aiStory {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 12))
                            .foregroundColor(.purple.opacity(0.6))

                        Text(story)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            Task {
                await InventoryManager.shared.loadItems()
                onDismiss()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                Text(NSLocalizedString("确认", comment: "Confirm button"))
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
                name: "协和医院急诊室",
                type: .hospital,
                coordinate: .init(latitude: 0, longitude: 0)
            ),
            items: [
                CollectedItem(
                    definition: ItemDefinition(
                        id: "ai_12345678",
                        name: "「最后的希望」应急包",
                        description: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它...",
                        category: .medical,
                        icon: "cross.case.fill",
                        rarity: .epic
                    ),
                    quality: .good,
                    quantity: 1,
                    aiName: "「最后的希望」应急包",
                    aiStory: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它...",
                    isAIGenerated: true
                ),
                CollectedItem(
                    definition: ItemDefinition(
                        id: "ai_87654321",
                        name: "护士站的咖啡罐头",
                        description: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。",
                        category: .food,
                        icon: "cup.and.saucer.fill",
                        rarity: .rare
                    ),
                    quality: .worn,
                    quantity: 1,
                    aiName: "护士站的咖啡罐头",
                    aiStory: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。",
                    isAIGenerated: true
                ),
                CollectedItem(
                    definition: ItemDefinition(
                        id: "ai_11112222",
                        name: "急诊科常备止痛片",
                        description: "瓶身上还贴着患者的名字，这些药片可能是某个人最后的希望。",
                        category: .medical,
                        icon: "pills.fill",
                        rarity: .uncommon
                    ),
                    quality: .pristine,
                    quantity: 2,
                    aiName: "急诊科常备止痛片",
                    aiStory: "瓶身上还贴着患者的名字，这些药片可能是某个人最后的希望。",
                    isAIGenerated: true
                )
            ]
        ),
        onDismiss: {}
    )
}
