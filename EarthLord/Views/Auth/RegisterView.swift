//
//  RegisterView.swift
//  EarthLord
//
//  Created by Yu Lei on 26/12/2025.
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 头部说明
                        headerView

                        // 输入表单
                        formView

                        // 注册按钮
                        registerButton

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("创建账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("注册成功", isPresented: $showSuccessAlert) {
            Button("好的") {
                dismiss()
            }
        } message: {
            Text("请查收验证邮件，验证后即可登录")
        }
    }

    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("加入地球争霸")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("创建账号，开始你的领地征服之旅")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 表单视图
    private var formView: some View {
        VStack(spacing: 16) {
            // 用户名输入
            inputField(
                title: "用户名",
                placeholder: "给自己取个响亮的名字",
                text: $username,
                keyboardType: .default
            )

            // 邮箱输入
            inputField(
                title: "邮箱",
                placeholder: "用于登录和找回密码",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("", text: $password)
                    .placeholder(when: password.isEmpty) {
                        Text("至少6个字符")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .textContentType(.newPassword)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
            }

            // 确认密码
            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("", text: $confirmPassword)
                    .placeholder(when: confirmPassword.isEmpty) {
                        Text("再次输入密码")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .textContentType(.newPassword)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding()
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(passwordMismatch ? ApocalypseTheme.danger.opacity(0.5) : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )

                if passwordMismatch {
                    Text("两次输入的密码不一致")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }
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

    // MARK: - 输入框组件
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - 注册按钮
    private var registerButton: some View {
        Button(action: performRegister) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isLoading ? "注册中..." : "创建账号")
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
        .disabled(!isFormValid || isLoading)
        .opacity(isFormValid ? 1.0 : 0.6)
    }

    // MARK: - 表单验证
    private var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    // MARK: - 执行注册
    private func performRegister() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthManager.shared.signUp(
                    email: email,
                    password: password,
                    username: username
                )
                showSuccessAlert = true
            } catch {
                errorMessage = AuthManager.shared.errorMessage
            }
            isLoading = false
        }
    }
}

#Preview {
    RegisterView()
}
