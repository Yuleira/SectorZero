//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面
//  显示圈地模块的实时调试日志，支持日志清空和导出
//  ＋ 模拟场景注入（无需出门）
//

#if DEBUG
import SwiftUI

/// 圈地功能测试界面
/// 注意：此视图不要套 NavigationStack！它是从 TestMenuView 导航进来的
struct TerritoryTestView: View {

    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var territoryManager = TerritoryManager.shared
    @ObservedObject private var logger = TerritoryLogger.shared

    @State private var lastSimScenario: TerritorySimScenario?
    @State private var showSwitchTabHint = false

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 模拟控制区
            simulationSection
                .padding(.vertical, 12)
                .background(ApocalypseTheme.background)

            Divider()

            // 日志区域
            logArea

            Divider()

            // 底部按钮栏
            buttonBar
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(String(localized: "test_territory"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态指示器

    private var statusIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(locationManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(locationManager.isTracking
                     ? String(localized: "territory_tracking_active")
                     : String(localized: "territory_not_tracking"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(locationManager.isTracking ? .green : ApocalypseTheme.textSecondary)
                Spacer()
                Text(String(format: String(localized: "territory_logs_count_format"), logger.logs.count))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            HStack {
                Toggle(isOn: $logger.isDebugMode) {
                    HStack(spacing: 6) {
                        Image(systemName: "ant.fill")
                            .font(.system(size: 12))
                            .foregroundColor(logger.isDebugMode ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                        Text(String(localized: "territory_debug_mode"))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.warning))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 模拟控制区

    private var simulationSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // 标题
            HStack {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("圈地模拟（无需 GPS）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.warning)
                Spacer()
                if showSwitchTabHint {
                    Text("→ 切到地图 Tab 查看结果")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.info)
                        .transition(.opacity)
                }
            }

            // 场景按钮（A：验证测试）
            Text("A. 验证场景")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)

            ForEach(TerritorySimScenario.allCases) { scenario in
                Button {
                    logger.clear()
                    locationManager.simulateClosedTerritory(scenario)
                    lastSimScenario = scenario
                    withAnimation { showSwitchTabHint = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation { showSwitchTabHint = false }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(scenario.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        if lastSimScenario == scenario {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        lastSimScenario == scenario
                                            ? ApocalypseTheme.primary.opacity(0.6)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }

            // 场景按钮（B：离线队列测试）
            Divider()
                .padding(.vertical, 2)

            Text("B. 离线队列测试")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)

            HStack(spacing: 8) {
                // 保存虚拟待上传
                Button {
                    territoryManager.savePendingUpload(
                        coordinates: TerritorySimScenario.validSquare.coordinates,
                        area: 2500,
                        startTime: Date().addingTimeInterval(-120),
                        distanceWalked: 175
                    )
                    logger.log("📦 已保存虚拟待上传领地到本地", type: .info)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                        Text("保存待上传")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.warning.opacity(0.8))
                    )
                }

                // 状态指示
                VStack(spacing: 4) {
                    Circle()
                        .fill(territoryManager.hasPendingUpload ? ApocalypseTheme.warning : Color.gray.opacity(0.4))
                        .frame(width: 12, height: 12)
                    Text(territoryManager.hasPendingUpload ? "有待上传" : "无待上传")
                        .font(.system(size: 11))
                        .foregroundColor(territoryManager.hasPendingUpload
                                         ? ApocalypseTheme.warning
                                         : ApocalypseTheme.textMuted)
                }
                .frame(width: 60)

                // 清除待上传
                Button {
                    territoryManager.clearPendingUpload()
                    logger.log("📦 待上传数据已清除", type: .info)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("清除待上传")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.5))
                    )
                }
                .disabled(!territoryManager.hasPendingUpload)
                .opacity(territoryManager.hasPendingUpload ? 1 : 0.4)
            }

            Text("保存后切到地图 Tab，会自动触发上传重试")
                .font(.system(size: 10))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 日志区域

    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if logger.logs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(String(localized: "territory_no_logs"))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(localized: "territory_logs_empty_hint"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: logger.logs.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func logEntryView(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(entry.type.emoji)
                .font(.system(size: 12))
            Text(entry.displayText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(logColor(for: entry.type))
        }
        .padding(.vertical, 2)
    }

    private func logColor(for type: LogType) -> Color {
        switch type {
        case .info:    return ApocalypseTheme.textPrimary
        case .success: return .green
        case .warning: return ApocalypseTheme.warning
        case .error:   return ApocalypseTheme.danger
        }
    }

    // MARK: - 底部按钮栏

    private var buttonBar: some View {
        HStack(spacing: 16) {
            Button {
                logger.clear()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(String(localized: "territory_clear_logs"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(logger.logs.isEmpty ? ApocalypseTheme.textMuted : ApocalypseTheme.danger)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(logger.logs.isEmpty
                                        ? ApocalypseTheme.textMuted.opacity(0.3)
                                        : ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .disabled(logger.logs.isEmpty)

            ShareLink(item: logger.export()) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "territory_export_logs"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(logger.logs.isEmpty ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(logger.logs.isEmpty
                                        ? ApocalypseTheme.textMuted.opacity(0.3)
                                        : ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .disabled(logger.logs.isEmpty)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
    }
}
#endif
