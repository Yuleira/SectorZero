//
//  LoginView.swift
//  EarthLord
//
//  Created by Yu Lei on 26/12/2025.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isAppleLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)

                    // Logo 和标题
                    headerView

                    // 输入表单
                    formView

                    // 登录按钮
                    loginButton

                    // 分隔线
                    dividerView

                    // Apple 登录
                    appleSignInButton

                    // 注册入口
                    registerLink

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }

    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 16) {
            // App 图标
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("地球新主")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("用脚步丈量世界，用领地征服地球")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 表单视图
    private var formView: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("", text: $email)
                    .placeholder(when: email.isEmpty) {
                        Text("请输入邮箱")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
            }

            // 密码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("", text: $password)
                    .placeholder(when: password.isEmpty) {
                        Text("请输入密码")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .textContentType(.password)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
            }

            // 错误提示
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 登录按钮
    private var loginButton: some View {
        Button(action: performLogin) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isLoading ? "登录中..." : "登录")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading || email.isEmpty || password.isEmpty)
        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
    }

    // MARK: - 分隔线
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("或")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 16)

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Apple 登录按钮
    private var appleSignInButton: some View {
        Button(action: performAppleSignIn) {
            HStack {
                if isAppleLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .padding(.trailing, 8)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                }
                Text(isAppleLoading ? "登录中..." : "通过 Apple 登录")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(12)
        }
        .disabled(isAppleLoading || isLoading)
    }

    // MARK: - 注册链接
    private var registerLink: some View {
        HStack {
            Text("还没有账号？")
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button("立即注册") {
                showRegister = true
            }
            .foregroundColor(ApocalypseTheme.primary)
            .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    // MARK: - 执行登录
    private func performLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthManager.shared.signIn(email: email, password: password)
            } catch {
                errorMessage = AuthManager.shared.errorMessage
            }
            isLoading = false
        }
    }

    // MARK: - 执行 Apple 登录
    private func performAppleSignIn() {
        isAppleLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthManager.shared.signInWithApple()
            } catch {
                // 用户取消不显示错误
                if !String(describing: error).contains("1001") {
                    errorMessage = AuthManager.shared.errorMessage
                }
            }
            isAppleLoading = false
        }
    }
}

// MARK: - Placeholder 扩展
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    LoginView()
}
