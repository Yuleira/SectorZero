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

    // Antenna pulse
    @State private var antennaPulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Background artwork (pinned to screen size)
                Image("login_bg_artwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Layer 2: Gradient overlay for readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Layer 3: Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)

                        // Header: icon + title + subtitle
                        headerView

                        // Glassmorphism form card
                        VStack(spacing: 16) {
                            tabSelector

                            if selectedTab == 0 {
                                loginView
                            } else {
                                registerView
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                        // Social sign-in
                        dividerView
                        thirdPartyLoginView

                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 28)
                }

                // Toast overlay
                if showToast {
                    toastView
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { _, newValue in
            if newValue && authManager.needsPasswordSetup {
                // State handled by AuthManager, UI auto-updates
            }
        }
    }

    // MARK: - Header (Icon + Title + Subtitle)

    private var headerView: some View {
        VStack(spacing: 16) {
            // Hardcore antenna icon with glow + pulse
            Image(systemName: "antenna.radiowaves.left.and.right")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(ApocalypseTheme.primary)
                .scaleEffect(antennaPulse ? 1.08 : 1.0)
                .opacity(antennaPulse ? 1.0 : 0.8)
                .shadow(color: ApocalypseTheme.primary.opacity(antennaPulse ? 0.7 : 0.4), radius: antennaPulse ? 30 : 20, x: 0, y: 0)
                .shadow(color: ApocalypseTheme.primary.opacity(0.25), radius: 50, x: 0, y: 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        antennaPulse = true
                    }
                }

            // Title — bold, tight tracking
            Text("auth_app_title")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .tracking(-1)

            // Subtitle
            Text("auth_app_slogan")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .tracking(1)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "auth_login", index: 0)
            tabButton(title: "auth_register", index: 1)
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func tabButton(title: LocalizedStringKey, index: Int) -> some View {
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
                placeholder: String(localized: "auth_email_placeholder"),
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            secureInputField(
                icon: "lock.fill",
                placeholder: String(localized: "auth_password_placeholder"),
                text: $loginPassword
            )

            // 错误提示
            errorMessageView

            // 登录按钮
            primaryButton(
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_login"),
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
                Text("auth_forgot_password")
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

            Text("auth_enter_email_for_code")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 邮箱输入
            inputField(
                icon: "envelope.fill",
                placeholder: String(localized: "auth_email_placeholder"),
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            // 错误提示
            errorMessageView

            // 发送验证码按钮
            primaryButton(
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_send_code"),
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

            Text("auth_enter_code")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("auth_code_sent_to \(registerEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入
            otpInputField(text: $registerCode)

            // 错误提示
            errorMessageView

            // 验证按钮
            primaryButton(
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_verify"),
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

            Text("auth_set_password")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("auth_set_password_hint")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 密码输入
            secureInputField(
                icon: "lock.fill",
                placeholder: String(localized: "auth_password_placeholder"),
                text: $registerPassword
            )

            // 确认密码
            secureInputField(
                icon: "lock.fill",
                placeholder: String(localized: "auth_confirm_password"),
                text: $registerConfirmPassword
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("auth_password_mismatch")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 错误提示
            errorMessageView

            // 完成注册按钮
            primaryButton(
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_complete_registration"),
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
            .navigationTitle(Text("auth_forgot_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showForgotPassword = false
                        authManager.resetFlowState()
                    } label: {
                        Text("common_cancel")
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

            Text("auth_enter_email_for_code")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            inputField(
                icon: "envelope.fill",
                placeholder: String(localized: "auth_email_placeholder"),
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
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_send_code"),
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

            Text("auth_enter_code")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("auth_code_sent_to \(resetEmail)")
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
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "auth_verify"),
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

            Text("auth_set_password")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            secureInputField(
                icon: "lock.fill",
                placeholder: String(localized: "auth_password_placeholder"),
                text: $resetPassword
            )

            secureInputField(
                icon: "lock.fill",
                placeholder: String(localized: "auth_confirm_password"),
                text: $resetConfirmPassword
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("auth_password_mismatch")
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
                title: authManager.isLoading ? String(localized: "common_loading") : String(localized: "common_confirm"),
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

    // MARK: - Divider
    private var dividerView: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)

            Text("auth_or_sign_in_with")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.4))
                .fixedSize()

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - Social Sign-In (Compact Circles)
    private var thirdPartyLoginView: some View {
        HStack(spacing: 20) {
            if AppConfig.Features.enableAppleSignIn {
                Button {
                    Task { await authManager.signInWithApple() }
                } label: {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(authManager.isLoading)
            }

            if AppConfig.Features.enableGoogleSignIn {
                Button {
                    Task { await authManager.signInWithGoogle() }
                } label: {
                    googleLogo
                        .frame(width: 20, height: 20)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(authManager.isLoading)
            }
        }
    }

    // MARK: - Google Logo (Arc-based G)
    private var googleLogo: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let center = CGPoint(x: s / 2, y: s / 2)
            let outer = s * 0.48
            let thick = s * 0.17

            // Color segments: Red (top-left), Yellow (bottom-left), Green (bottom-right), Blue (right)
            let segments: [(Color, Angle, Angle)] = [
                (Color(red: 0.92, green: 0.26, blue: 0.21), .degrees(-150), .degrees(-30)),  // Red: top-left arc
                (Color(red: 0.98, green: 0.74, blue: 0.02), .degrees(-30), .degrees(30)),      // Yellow: left arc (mapped to bottom-left)
                (Color(red: 0.20, green: 0.66, blue: 0.33), .degrees(30), .degrees(90)),       // Green: bottom-right arc
                (Color(red: 0.26, green: 0.52, blue: 0.96), .degrees(90), .degrees(210)),      // Blue: right arc
            ]

            for (color, start, end) in segments {
                var path = Path()
                path.addArc(center: center, radius: outer - thick / 2, startAngle: start, endAngle: end, clockwise: false)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: thick, lineCap: .butt))
            }

            // Blue horizontal bar (the crossbar of the G)
            let barRect = CGRect(x: s * 0.48, y: s * 0.42, width: s * 0.38, height: thick)
            context.fill(Path(barRect), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
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

    // Input field with fixed height
    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 22)

            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // Secure input field with fixed height
    private func secureInputField(
        icon: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 22)

            SecureField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .textContentType(.password)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // OTP input field with fixed height
    private func otpInputField(text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 22)

            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text("auth_code_placeholder")
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .keyboardType(.numberPad)
                .foregroundColor(.white)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > 6 {
                        text.wrappedValue = String(newValue.prefix(6))
                    }
                    text.wrappedValue = newValue.filter { $0.isNumber }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // Primary action button
    private func primaryButton(
        title: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: isEnabled
                    ? [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]
                    : [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(isEnabled ? .white : Color.white.opacity(0.4))
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }

    // 重发验证码按钮
    private func resendButton(countdown: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if countdown > 0 {
                Text("auth_resend_countdown \(countdown)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Text("auth_resend_code")
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
                Text("auth_back")
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
