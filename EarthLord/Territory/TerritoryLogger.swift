//
//  TerritoryLogger.swift
//  EarthLord
//
//  Created by Claude on 05/01/2026.
//
//  圈地功能测试日志管理器
//  用于在 App 内显示调试日志，方便真机测试时查看圈地模块的运行状态
//

import Foundation
import Combine

/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 日志类型对应的颜色标识
    var emoji: String {
        switch self {
        case .info: return "📝"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    /// 格式化的显示文本（短时间格式）
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }

    /// 格式化的导出文本（完整时间格式）
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }
}

/// 圈地功能日志管理器
/// 单例模式 + ObservableObject，支持 SwiftUI 数据绑定
final class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - 发布属性

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    /// 调试模式开关（开启后即使未追踪也记录位置日志）
    @Published var isDebugMode: Bool = false

    // MARK: - 私有属性

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - 初始化

    private init() {
        debugLog("📋 [日志管理器] 初始化完成")
    }

    // MARK: - 公共方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型（默认为 info）
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 添加新日志
            self.logs.append(entry)

            // 限制日志数量
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新显示文本
            self.updateLogText()

            // 同时输出到控制台
            debugLog("📋 [圈地日志] \(entry.displayText)")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
            debugLog("📋 [日志管理器] 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let exportTime = formatter.string(from: Date())

        var text = """
        === 圈地功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        for entry in logs {
            text += entry.exportText + "\n"
        }

        return text
    }

    // MARK: - 私有方法

    /// 更新显示文本
    private func updateLogText() {
        logText = logs.map { $0.displayText }.joined(separator: "\n")
    }
}
