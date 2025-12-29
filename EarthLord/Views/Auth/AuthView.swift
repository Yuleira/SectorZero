//
//  AuthView.swift
//  EarthLord
//
//  Created by Yu Lei on 29/12/2025.
//

import SwiftUI

/// 认证页面
/// 包含登录、注册（三步流程）、忘记密码功能
struct AuthView: View {
    /// 认证管理器（观察共享单例）
    @ObservedObject private var authManager = AuthManager.shared

    // MARK: - 状态属性

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab = 0

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerCode = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    // 忘记密码
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var resetCode = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep = 1
    @State private var resetOtpSent = false

    // 倒计时
    @State private var countdown = 0
    @State private var resetCountdown = 0
    @State private var countdownTimer: Timer?
    @State private var resetCountdownTimer: Timer?

    // Toast
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Logo 和标题
                    headerView

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerView

                    // 第三方登录
                    thirdPartyLoginView

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { _, newValue in
            // 注册流程：OTP验证成功后自动进入第三步
            if newValue && authManager.needsPasswordSetup {
                // 状态已经由 AuthManager 处理，UI 会自动更新
            }
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.08),
                Color(red: 0.10, green: 0.08, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

            Text("地球新主")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("用脚步丈量世界，用领地征服地球")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 40)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                authManager.clearError()
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(selectedTab == index ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedTab == index
                    ? LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
        }
    }

    // MARK: - ==================== 登录视图 ====================
    private var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            inputField(
                icon: "envelope.fill",
                placeholder: "请输入邮箱",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            secureInputField(
                icon: "lock.fill",
                placeholder: "请输入密码",
                text: $loginPassword
            )

            // 错误提示
            errorMessageView

            // 登录按钮
            primaryButton(
                title: authManager.isLoading ? "登录中..." : "登录",
                isEnabled: !loginEmail.isEmpty && !loginPassword.isEmpty && !authManager.isLoading
            ) {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }

            // 忘记密码链接
            Button {
                resetStep = 1
                resetEmail = ""
                resetCode = ""
                resetPassword = ""
                resetConfirmPassword = ""
                resetOtpSent = false
                showForgotPassword = true
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - ==================== 注册视图（三步流程） ====================
    private var registerView: some View {
        VStack(spacing: 20) {
            // 根据状态显示不同步骤
            if authManager.otpVerified && authManager.needsPasswordSetup {
                // 第三步：设置密码
                registerStep3View
            } else if authManager.otpSent {
                // 第二步：验证码验证
                registerStep2View
            } else {
                // 第一步：输入邮箱
                registerStep1View
            }
        }
    }

    // 第一步：邮箱输入
    private var registerStep1View: some View {
        VStack(spacing: 20) {
            // 步骤指示
            stepIndicator(current: 1, total: 3)

            Text("输入邮箱获取验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 邮箱输入
            inputField(
                icon: "envelope.fill",
                placeholder: "请输入邮箱",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            // 错误提示
            errorMessageView

            // 发送验证码按钮
            primaryButton(
                title: authManager.isLoading ? "发送中..." : "发送验证码",
                isEnabled: isValidEmail(registerEmail) && !authManager.isLoading
            ) {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
        }
    }

    // 第二步：验证码验证
    private var registerStep2View: some View {
        VStack(spacing: 20) {
            // 步骤指示
            stepIndicator(current: 2, total: 3)

            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(registerEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入
            otpInputField(text: $registerCode)

            // 错误提示
            errorMessageView

            // 验证按钮
            primaryButton(
                title: authManager.isLoading ? "验证中..." : "验证",
                isEnabled: registerCode.count == 6 && !authManager.isLoading
            ) {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                }
            }

            // 重发验证码
            resendButton(countdown: countdown) {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }

            // 返回上一步
            backButton {
                authManager.resetFlowState()
                registerCode = ""
            }
        }
    }

    // 第三步：设置密码
    private var registerStep3View: some View {
        VStack(spacing: 20) {
            // 步骤指示
            stepIndicator(current: 3, total: 3)

            Text("设置登录密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("请设置一个安全的密码以完成注册")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 密码输入
            secureInputField(
                icon: "lock.fill",
                placeholder: "请输入密码（至少6位）",
                text: $registerPassword
            )

            // 确认密码
            secureInputField(
                icon: "lock.fill",
                placeholder: "请确认密码",
                text: $registerConfirmPassword
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("两次输入的密码不一致")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 错误提示
            errorMessageView

            // 完成注册按钮
            primaryButton(
                title: authManager.isLoading ? "提交中..." : "完成注册",
                isEnabled: isPasswordValid && !authManager.isLoading
            ) {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
        }
    }

    private var isPasswordValid: Bool {
        registerPassword.count >= 6 && registerPassword == registerConfirmPassword
    }

    // MARK: - ==================== 忘记密码弹窗 ====================
    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        // 根据步骤显示不同内容
                        switch resetStep {
                        case 1:
                            resetStep1View
                        case 2:
                            resetStep2View
                        case 3:
                            resetStep3View
                        default:
                            EmptyView()
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetFlowState()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // 重置密码第一步：输入邮箱
    private var resetStep1View: some View {
        VStack(spacing: 20) {
            stepIndicator(current: 1, total: 3)

            Text("输入注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            inputField(
                icon: "envelope.fill",
                placeholder: "请输入邮箱",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            primaryButton(
                title: authManager.isLoading ? "发送中..." : "发送验证码",
                isEnabled: isValidEmail(resetEmail) && !authManager.isLoading
            ) {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        resetOtpSent = true
                        resetStep = 2
                        startResetCountdown()
                    }
                }
            }
        }
    }

    // 重置密码第二步：验证码验证
    private var resetStep2View: some View {
        VStack(spacing: 20) {
            stepIndicator(current: 2, total: 3)

            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(resetEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            otpInputField(text: $resetCode)

            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            primaryButton(
                title: authManager.isLoading ? "验证中..." : "验证",
                isEnabled: resetCode.count == 6 && !authManager.isLoading
            ) {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
                    if authManager.otpVerified {
                        resetStep = 3
                    }
                }
            }

            resendButton(countdown: resetCountdown) {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        startResetCountdown()
                    }
                }
            }

            backButton {
                resetStep = 1
                resetCode = ""
                authManager.clearError()
            }
        }
    }

    // 重置密码第三步：设置新密码
    private var resetStep3View: some View {
        VStack(spacing: 20) {
            stepIndicator(current: 3, total: 3)

            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            secureInputField(
                icon: "lock.fill",
                placeholder: "请输入新密码（至少6位）",
                text: $resetPassword
            )

            secureInputField(
                icon: "lock.fill",
                placeholder: "请确认新密码",
                text: $resetConfirmPassword
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("两次输入的密码不一致")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            primaryButton(
                title: authManager.isLoading ? "提交中..." : "重置密码",
                isEnabled: resetPassword.count >= 6 && resetPassword == resetConfirmPassword && !authManager.isLoading
            ) {
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                    }
                }
            }
        }
    }

    // MARK: - ==================== 分隔线 ====================
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 12)

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - ==================== 第三方登录 ====================
    private var thirdPartyLoginView: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮（符合 Apple Human Interface Guidelines）
            if AppConfig.Features.enableAppleSignIn {
                Button {
                    Task {
                        await authManager.signInWithApple()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("通过 Apple 登录")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(authManager.isLoading)
            }

            // Google 登录按钮
            if AppConfig.Features.enableGoogleSignIn {
                Button {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Google "G" Logo
                        googleLogo
                            .frame(width: 18, height: 18)
                        Text("通过 Google 登录")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(Color(red: 0.26, green: 0.26, blue: 0.26))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .disabled(authManager.isLoading)
            }
        }
    }

    // MARK: - Google Logo（多色 G 图标）
    private var googleLogo: some View {
        // Google 官方多色 "G" 图标的 SwiftUI 实现
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                // 蓝色部分（右侧）
                Path { path in
                    path.move(to: CGPoint(x: size * 0.96, y: size * 0.5))
                    path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.5))
                    path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.68))
                    path.addLine(to: CGPoint(x: size * 0.82, y: size * 0.68))
                    path.addCurve(
                        to: CGPoint(x: size * 0.5, y: size * 0.96),
                        control1: CGPoint(x: size * 0.78, y: size * 0.84),
                        control2: CGPoint(x: size * 0.66, y: size * 0.96)
                    )
                }
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))

                // 绿色部分（右下）
                Path { path in
                    path.move(to: CGPoint(x: size * 0.5, y: size * 0.96))
                    path.addCurve(
                        to: CGPoint(x: size * 0.04, y: size * 0.5),
                        control1: CGPoint(x: size * 0.24, y: size * 0.96),
                        control2: CGPoint(x: size * 0.04, y: size * 0.76)
                    )
                }
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: size * 0.18)

                // 黄色部分（左下）
                Path { path in
                    path.move(to: CGPoint(x: size * 0.04, y: size * 0.5))
                    path.addCurve(
                        to: CGPoint(x: size * 0.26, y: size * 0.16),
                        control1: CGPoint(x: size * 0.04, y: size * 0.34),
                        control2: CGPoint(x: size * 0.12, y: size * 0.22)
                    )
                }
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: size * 0.18)

                // 红色部分（左上）
                Path { path in
                    path.move(to: CGPoint(x: size * 0.26, y: size * 0.16))
                    path.addCurve(
                        to: CGPoint(x: size * 0.96, y: size * 0.5),
                        control1: CGPoint(x: size * 0.46, y: size * 0.04),
                        control2: CGPoint(x: size * 0.78, y: size * 0.14)
                    )
                }
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: size * 0.18)
            }
        }
    }

    // MARK: - ==================== Toast 视图 ====================
    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - ==================== 通用组件 ====================

    // 错误提示
    private var errorMessageView: some View {
        Group {
            if let error = authManager.errorMessage {
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

    // 步骤指示器
    private func stepIndicator(current: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { step in
                Circle()
                    .fill(step <= current ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)

                if step < total {
                    Rectangle()
                        .fill(step < current ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 40, height: 2)
                }
            }
        }
    }

    // 输入框
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // 密码输入框
    private func secureInputField(
        icon: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            SecureField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .textContentType(.password)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // OTP 验证码输入框
    private func otpInputField(text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text("请输入6位验证码")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .keyboardType(.numberPad)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .onChange(of: text.wrappedValue) { _, newValue in
                    // 限制为6位数字
                    if newValue.count > 6 {
                        text.wrappedValue = String(newValue.prefix(6))
                    }
                    // 只允许数字
                    text.wrappedValue = newValue.filter { $0.isNumber }
                }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    // 主按钮
    private func primaryButton(
        title: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: isEnabled
                    ? [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]
                    : [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }

    // 重发验证码按钮
    private func resendButton(countdown: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Text("重新发送验证码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .disabled(countdown > 0 || authManager.isLoading)
    }

    // 返回按钮
    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "chevron.left")
                Text("返回上一步")
            }
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - ==================== 辅助方法 ====================

    // 邮箱验证
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // 开始注册倒计时
    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                countdownTimer?.invalidate()
            }
        }
    }

    // 开始重置密码倒计时
    private func startResetCountdown() {
        resetCountdown = 60
        resetCountdownTimer?.invalidate()
        resetCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resetCountdown > 0 {
                resetCountdown -= 1
            } else {
                resetCountdownTimer?.invalidate()
            }
        }
    }

    // 显示 Toast
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Placeholder 扩展
extension View {
    /// 为 TextField/SecureField 添加自定义占位符
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
    AuthView()
}
