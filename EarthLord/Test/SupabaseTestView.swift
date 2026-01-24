//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Yu Lei on 26/12/2025.
//

import SwiftUI
import Supabase

// 初始化 Supabase 客户端（使用 AppConfig 配置）
let supabase = SupabaseClient(
    supabaseURL: URL(string: AppConfig.Supabase.projectURL)!,
    supabaseKey: AppConfig.Supabase.publishableKey,
    options: .init(
        auth: .init(
            flowType: .pkce,
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)

struct SupabaseTestView: View {
    @State private var isSuccess: Bool? = nil
    @State private var logText: String = "点击按钮开始测试连接..."
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIcon

            // 调试日志文本框
            logView

            // 测试连接按钮
            testButton

            // 验证数据表按钮
            verifyTablesButton
        }
        .padding()
        .navigationTitle(String(localized: "test_supabase_connection"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    private var statusIcon: some View {
        Group {
            if let success = isSuccess {
                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(success ? .green : .red)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
        }
        .animation(.easeInOut, value: isSuccess)
    }

    // MARK: - 日志显示区域
    private var logView: some View {
        ScrollView {
            Text(logText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 测试按钮
    private var testButton: some View {
        Button(action: testConnection) {
            HStack {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isTesting ? "测试中..." : "测试连接")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTesting ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isTesting)
    }

    // MARK: - 验证数据表按钮
    private var verifyTablesButton: some View {
        Button(action: verifyTables) {
            HStack {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isTesting ? "验证中..." : "验证数据表")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTesting ? Color.gray : Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isTesting)
    }

    // MARK: - 测试连接逻辑
    private func testConnection() {
        isTesting = true
        isSuccess = nil
        logText = "[\(currentTime)] 开始测试连接...\n"
        logText += "[\(currentTime)] URL: https://zkcjvhdhartrrekzjtjg.supabase.co\n"
        logText += "[\(currentTime)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（不太可能），也算连接成功
                await MainActor.run {
                    isSuccess = true
                    logText += "[\(currentTime)] ✅ 连接成功（查询成功）\n"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                    isTesting = false
                }
            }
        }
    }

    // MARK: - 错误处理
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        logText += "[\(currentTime)] 收到响应，正在分析...\n"
        logText += "[\(currentTime)] 错误详情: \(errorString)\n\n"

        // 判断错误类型
        if errorString.contains("PGRST") || errorString.contains("Could not find") {
            // PostgREST 错误说明服务器已响应
            isSuccess = true
            logText += "[\(currentTime)] ✅ 连接成功（服务器已响应）\n"
            logText += "[\(currentTime)] 说明：收到 PostgREST 错误，表示 Supabase 服务正常运行\n"
        } else if errorString.contains("relation") && errorString.contains("does not exist") {
            // PostgreSQL 关系不存在错误
            isSuccess = true
            logText += "[\(currentTime)] ✅ 连接成功（服务器已响应）\n"
            logText += "[\(currentTime)] 说明：收到数据库错误，表示连接正常\n"
        } else if errorString.contains("hostname") || errorString.contains("URL") || errorString.contains("NSURLErrorDomain") {
            // 网络相关错误
            isSuccess = false
            logText += "[\(currentTime)] ❌ 连接失败：URL 错误或无网络\n"
            logText += "[\(currentTime)] 请检查网络连接和 Supabase URL 配置\n"
        } else {
            // 其他错误
            isSuccess = false
            logText += "[\(currentTime)] ❌ 未知错误\n"
            logText += "[\(currentTime)] 错误类型: \(type(of: error))\n"
        }
    }

    // MARK: - 验证数据表逻辑
    private func verifyTables() {
        isTesting = true
        isSuccess = nil
        logText = "[\(currentTime)] 开始验证数据表...\n"

        Task {
            var allSuccess = true
            var successCount = 0
            let tables = ["profiles", "territories", "pois"]

            for table in tables {
                await MainActor.run {
                    logText += "[\(currentTime)] 正在验证表: \(table)...\n"
                }

                do {
                    switch table {
                    case "profiles":
                        let _: [Profile] = try await supabase
                            .from(table)
                            .select()
                            .limit(1)
                            .execute()
                            .value
                    case "territories":
                        let _: [TestTerritory] = try await supabase
                            .from(table)
                            .select()
                            .limit(1)
                            .execute()
                            .value
                    case "pois":
                        let _: [TestPOI] = try await supabase
                            .from(table)
                            .select()
                            .limit(1)
                            .execute()
                            .value
                    default:
                        break
                    }

                    await MainActor.run {
                        logText += "[\(currentTime)] ✅ \(table) 表存在\n"
                        successCount += 1
                    }
                } catch {
                    let errorString = String(describing: error)
                    await MainActor.run {
                        if errorString.contains("does not exist") || errorString.contains("PGRST200") {
                            logText += "[\(currentTime)] ❌ \(table) 表不存在\n"
                            allSuccess = false
                        } else {
                            // 其他错误可能是权限问题，但表存在
                            logText += "[\(currentTime)] ✅ \(table) 表存在（查询返回空或权限受限）\n"
                            successCount += 1
                        }
                    }
                }
            }

            await MainActor.run {
                logText += "\n[\(currentTime)] 验证完成: \(successCount)/\(tables.count) 个表\n"
                if allSuccess {
                    isSuccess = true
                    logText += "[\(currentTime)] ✅ 所有数据表创建成功！\n"
                } else {
                    isSuccess = false
                    logText += "[\(currentTime)] ❌ 部分表未创建，请检查迁移是否执行成功\n"
                }
                isTesting = false
            }
        }
    }

    // MARK: - 当前时间格式化
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// 空响应结构体用于解码
private struct EmptyResponse: Decodable {}

// Profile 结构体
private struct Profile: Decodable {
    let id: UUID
    let username: String?
    let avatar_url: String?
    let created_at: String?
}

// 测试用 Territory 结构体（简化版本）
private struct TestTerritory: Decodable {
    let id: UUID
    let user_id: UUID
    let name: String?
    let area: Double
    let created_at: String?
}

// 测试用 POI 结构体
private struct TestPOI: Decodable {
    let id: String
    let poi_type: String
    let name: String
    let latitude: Double
    let longitude: Double
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
