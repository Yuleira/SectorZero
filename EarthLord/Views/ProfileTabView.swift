//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI
import Supabase

/// 个人页面
/// 显示用户信息、统计数据和账号操作
struct ProfileTabView: View {
    /// 认证管理器（使用 @ObservedObject 确保状态响应）
    @ObservedObject private var authManager = AuthManager.shared

    /// 语言管理器（用于显示当前语言）
    @StateObject private var languageManager = LanguageManager.shared

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert = false

    /// 是否正在退出
    @State private var isLoggingOut = false

    /// 删除账户弹窗控制
    @State private var showDeleteAccountSheet = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 用户信息区域
                Section {
                    userInfoCard
                }

                // MARK: - 统计数据（待实现数据获取后显示）
                // TODO: 从数据库获取用户统计数据后取消注释
                // Section("我的数据") {
                //     Label("领地数量: \(territoryCount)", systemImage: "flag.fill")
                //     Label("总面积: \(totalArea) m²", systemImage: "square.dashed")
                //     Label("发现 POI: \(poiCount)", systemImage: "mappin.circle.fill")
                // }

                // MARK: - 设置选项
                Section("设置".localized) {
                    NavigationLink {
                        Text("账号安全（待开发）".localized)
                    } label: {
                        Label("账号安全".localized, systemImage: "shield.fill")
                    }

                    NavigationLink {
                        Text("通知设置（待开发）".localized)
                    } label: {
                        Label("通知设置".localized, systemImage: "bell.fill")
                    }

                    NavigationLink {
                        Text("关于我们（待开发）".localized)
                    } label: {
                        Label("关于我们".localized, systemImage: "info.circle.fill")
                    }
                }

                // MARK: - App 设置
                Section("应用设置".localized) {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Label("语言".localized, systemImage: "globe")
                            Spacer()
                            Text(languageManager.currentLanguage.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: - 退出登录
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Label("退出登录".localized, systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                    }
                    .disabled(isLoggingOut)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAccountSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除账户".localized)
                            Spacer()
                        }
                    }
                } footer: {
                    Text("删除账户后，您的所有数据将被永久删除且无法恢复。".localized)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("个人".localized)
            .id(languageManager.refreshID)
            .alert("确认退出".localized, isPresented: $showLogoutAlert) {
                Button("取消".localized, role: .cancel) { }
                Button("退出".localized, role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("确定要退出登录吗？退出后需要重新登录。".localized)
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                DeleteAccountConfirmView(
                    isPresented: $showDeleteAccountSheet,
                    onError: { error in
                        deleteErrorMessage = error
                        showDeleteError = true
                    }
                )
            }
            .alert("删除失败".localized, isPresented: $showDeleteError) {
                Button("确定".localized, role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
                    // TODO: 加载网络头像
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // 用户名
                Text(username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 邮箱
                Text(email)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 用户ID（可选显示）
                if let userId = authManager.currentUser?.id {
                    Text("ID: \(userId.uuidString.prefix(8))...")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 编辑按钮
            Button {
                // TODO: 打开编辑资料页面
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 计算属性

    /// 用户名
    private var username: String {
        // 优先从 userMetadata 获取用户名
        if let name = authManager.currentUser?.userMetadata["username"]?.stringValue, !name.isEmpty {
            return name
        }
        // 其次使用邮箱前缀
        if let email = authManager.currentUser?.email {
            return String(email.split(separator: "@").first ?? "幸存者")
        }
        return "幸存者"
    }

    /// 邮箱
    private var email: String {
        authManager.currentUser?.email ?? "未设置邮箱"
    }

    /// 头像URL
    private var avatarUrl: String? {
        authManager.currentUser?.userMetadata["avatar_url"]?.stringValue
    }

    // MARK: - 方法

    /// 执行退出登录
    private func performLogout() {
        isLoggingOut = true
        Task {
            await authManager.signOut()
            // signOut 完成后，authManager.isAuthenticated 会变为 false
            // RootView 会自动切换到登录页面
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

// MARK: - 删除账户确认视图
struct DeleteAccountConfirmView: View {
    @Binding var isPresented: Bool
    var onError: (String) -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var confirmText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let requiredText = "删除"

    private var canDelete: Bool {
        confirmText == requiredText
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 40)

                Text("确认删除账户".localized)
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    Text("此操作不可撤销！".localized)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Text("删除账户后，以下数据将被永久删除：".localized)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("您的个人资料信息".localized, systemImage: "person.crop.circle")
                        Label("所有游戏进度和数据".localized, systemImage: "gamecontroller")
                        Label("登录凭证和认证信息".localized, systemImage: "key")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入「\(requiredText)」以确认操作：".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("请输入\(requiredText)".localized, text: $confirmText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task {
                            do {
                                try await authManager.deleteAccount()
                                isPresented = false
                            } catch {
                                onError(authManager.errorMessage ?? "删除账户失败，请稍后重试".localized)
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text("确认删除".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canDelete ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete || authManager.isLoading)

                    Button {
                        isPresented = false
                    } label: {
                        Text("取消".localized)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                print("📱 [删除账户] 显示删除确认页面")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 语言设置视图
struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } footer: {
                Text("切换语言后界面将立即更新".localized)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("语言设置".localized)
        .navigationBarTitleDisplayMode(.inline)
        .id(languageManager.refreshID)
    }
}
#Preview {
    ProfileTabView()
}
