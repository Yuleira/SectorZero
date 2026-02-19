//
//  TerritoryTestView.swift
//  EarthLord
//
//  Created by Claude on 05/01/2026.
//
//  圈地功能测试界面
//  显示圈地模块的实时调试日志，支持日志清空和导出
//

#if DEBUG
import SwiftUI

/// 圈地功能测试界面
/// 注意：此视图不要套 NavigationStack！它是从 TestMenuView 导航进来的
struct TerritoryTestView: View {

    // MARK: - 状态属性

    /// 定位管理器（监听追踪状态）
    @ObservedObject private var locationManager = LocationManager.shared

    /// 日志管理器（监听日志更新）
    @ObservedObject private var logger = TerritoryLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)

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

    // MARK: - 子视图

    /// 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 12) {
            // 第一行：追踪状态 + 日志条数
            HStack(spacing: 8) {
                // 状态圆点
                Circle()
                    .fill(locationManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                // 状态文字
                Text(locationManager.isTracking ? String(localized: "territory_tracking_active") : String(localized: "territory_not_tracking"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(locationManager.isTracking ? .green : ApocalypseTheme.textSecondary)

                Spacer()

                // 日志条数
                Text(String(format: String(localized: "territory_logs_count_format"), logger.logs.count))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 第二行：调试模式开关
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

                if logger.isDebugMode {
                    Text("map_record_all_gps_updates")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// 日志区域
    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if logger.logs.isEmpty {
                    // 空状态
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
                    .padding(.top, 100)
                } else {
                    // 日志列表
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                        }
                        // 底部锚点，用于自动滚动
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: logger.logs.count) { oldValue, newValue in
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 单条日志视图
    private func logEntryView(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // 类型图标
            Text(entry.type.emoji)
                .font(.system(size: 12))

            // 日志内容
            Text(entry.displayText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(logColor(for: entry.type))
        }
        .padding(.vertical, 2)
    }

    /// 根据日志类型返回颜色
    private func logColor(for type: LogType) -> Color {
        switch type {
        case .info:
            return ApocalypseTheme.textPrimary
        case .success:
            return .green
        case .warning:
            return ApocalypseTheme.warning
        case .error:
            return ApocalypseTheme.danger
        }
    }

    /// 底部按钮栏
    private var buttonBar: some View {
        HStack(spacing: 16) {
            // 清空按钮
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
                                .stroke(logger.logs.isEmpty ? ApocalypseTheme.textMuted.opacity(0.3) : ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .disabled(logger.logs.isEmpty)

            // 导出按钮
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
                                .stroke(logger.logs.isEmpty ? ApocalypseTheme.textMuted.opacity(0.3) : ApocalypseTheme.primary.opacity(0.5), lineWidth: 1)
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
