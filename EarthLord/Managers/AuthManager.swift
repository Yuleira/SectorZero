//
//  AuthManager.swift
//  EarthLord
//
//  Created by Yu Lei on 26/12/2025.
//

import Foundation
import Supabase
import Combine
import AuthenticationServices
import CryptoKit
import UIKit

// Google Sign-In SDK - 通过 SPM 安装后取消注释
import GoogleSignIn

/// 认证管理器
/// 负责处理所有认证相关的逻辑，包括注册、登录、找回密码等
///
/// 认证流程说明：
/// - 注册：发验证码 → 验证OTP（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证OTP（此时已登录）→ 设置新密码 → 完成
@MainActor
final class AuthManager: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有必要流程）
    /// 注意：OTP验证后如果需要设置密码，此值仍为 false
    @Published private(set) var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证成功后，注册流程需要强制设置密码）
    @Published private(set) var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published private(set) var currentUser: User?

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 是否仍在等待初始会话检查（启动时为 true，.initialSession 到达后变 false）
    @Published private(set) var isInitializing: Bool = true

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published private(set) var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published private(set) var otpVerified: Bool = false

    // MARK: - Apple 登录相关
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?
    /// Strong reference keeps the controller alive until the delegate fires.
    /// Without this the controller is deallocated immediately after performRequests()
    /// and the Apple sheet never appears (silent "unresponsive" bug).
    private var appleSignInController: ASAuthorizationController?
    /// Guards against a race condition where Supabase fires .signedOut (token_revoked)
    /// while revoking the old session during a new Apple Sign In handshake, causing
    /// handleSessionExpired() to reset isAuthenticated mid-login.
    private var isPerformingAppleSignIn = false

    // MARK: - 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - 初始化
    private override init() {
        super.init()
        setupAuthStateListener()
    }

    // MARK: - 设置认证状态监听
    /// 监听 Supabase 认证状态变化
    /// 当会话过期或用户登出时，自动重置状态并跳转到登录页
    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { return }

                debugLog("🔐 Auth Event: \(event), User: \(session?.user.email ?? "nil")")

                switch event {
                case .initialSession:
                    // 初始会话：检查用户是否已完成注册流程
                    self.currentUser = session?.user
                    // 如果有会话且不在密码设置流程中，则认为已认证
                    if session?.user != nil && !self.needsPasswordSetup {
                        self.isAuthenticated = true
                    } else if session == nil {
                        // 没有会话，确保未认证状态
                        self.isAuthenticated = false
                    }
                    self.isLoading = false
                    self.isInitializing = false

                case .signedIn:
                    // 登录成功
                    self.currentUser = session?.user
                    // 仅当不需要设置密码时才设为已认证
                    if !self.needsPasswordSetup {
                        self.isAuthenticated = true
                    }

                case .signedOut:
                    // 退出登录或会话过期：重置所有状态
                    // 这会触发 RootView 自动切换到登录页面
                    // Guard: Supabase fires .signedOut when revoking the old token
                    // during Apple Sign In — ignore it so the new session is not wiped.
                    guard !self.isPerformingAppleSignIn else {
                        debugLog("⚠️ .signedOut ignored — Apple Sign In handshake in progress")
                        break
                    }
                    self.handleSessionExpired()

                case .userUpdated:
                    // 用户信息更新
                    self.currentUser = session?.user

                case .tokenRefreshed:
                    // Token 刷新成功
                    self.currentUser = session?.user
                    debugLog("🔄 Token refreshed successfully")

                default:
                    break
                }
            }
        }
    }

    /// 处理会话过期
    /// 重置所有认证状态，UI 会自动响应并跳转到登录页
    private func handleSessionExpired() {
        debugLog("⚠️ Session expired or user signed out")
        currentUser = nil
        isAuthenticated = false
        needsPasswordSetup = false
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }

    // MARK: - ==================== 注册流程 ====================

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 调用 signInWithOTP 发送验证码邮件，shouldCreateUser 设为 true 允许创建新用户
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 使用 signInWithOTP 发送验证码，shouldCreateUser: true 允许创建新用户
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 6位验证码
    /// - Note: 验证成功后用户已登录，但需要设置密码才能完成注册流程
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        // ⚠️ 重要：在验证 OTP 之前先设置此标志
        // 因为验证成功后会触发 .signedIn 事件，authStateListener 会检查此标志
        // 如果不提前设置，会导致 isAuthenticated 被错误地设为 true
        needsPasswordSetup = true

        do {
            // 验证 OTP，type 为 .email（signInWithOTP 发送的验证码使用此类型）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功：用户已登录，但需要设置密码
            currentUser = session.user
            otpVerified = true
            // needsPasswordSetup 已在上面设置为 true
            // 注意：isAuthenticated 保持 false，因为还需要设置密码

            isLoading = false
        } catch {
            // 验证失败，重置标志
            needsPasswordSetup = false
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    /// - Note: OTP验证后必须调用此方法设置密码才能完成注册流程
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true
            otpSent = false
            otpVerified = false

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    /// 更新用户名
    func updateUsername(_ newUsername: String) async throws {
        let response = try await supabase.auth.update(
            user: UserAttributes(data: ["username": .string(newUsername)])
        )
        currentUser = response
    }

    // MARK: - ==================== 登录流程 ====================

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    /// - Note: 直接登录，成功后 isAuthenticated = true
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - ==================== 找回密码流程 ====================

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    /// - Note: 调用 resetPasswordForEmail 发送重置密码邮件
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送重置密码邮件（使用 Reset Password 模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 6位验证码
    /// - Note: 验证成功后用户已登录，可以设置新密码。注意 type 是 .recovery 不是 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        // ⚠️ 重要：在验证 OTP 之前先设置此标志
        // 因为验证成功后会触发 .signedIn 事件，authStateListener 会检查此标志
        needsPasswordSetup = true

        do {
            // 验证 OTP，type 为 .recovery（密码重置类型）
            // ⚠️ 重要：找回密码使用 .recovery 类型，不是 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功：用户已登录，可以设置新密码
            currentUser = session.user
            otpVerified = true
            // needsPasswordSetup 已在上面设置为 true
            // isAuthenticated 保持 false，等待设置新密码

            isLoading = false
        } catch {
            // 验证失败，重置标志
            needsPasswordSetup = false
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    /// - Note: 验证码验证后调用此方法设置新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true
            otpSent = false
            otpVerified = false

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - ==================== 第三方登录 ====================

    /// Apple 登录
    /// 使用 Sign in with Apple 获取 identity token，通过 Nonce 验证后交给 Supabase 认证
    ///
    /// 安全流程：
    /// 1. 生成随机 raw nonce（32字节随机字符串）
    /// 2. 计算 nonce 的 SHA256 哈希值
    /// 3. 将 hashed nonce 发送给 Apple 进行签名
    /// 4. Apple 返回包含 hashed nonce 的 identity token
    /// 5. 将 identity token 和 raw nonce 发送给 Supabase
    /// 6. Supabase 验证 token 中的 hashed nonce 是否与 raw nonce 的 SHA256 匹配
    ///
    /// 配置步骤：
    /// 1. 在 Xcode 的 Signing & Capabilities 中添加 "Sign in with Apple"
    /// 2. 在 Apple Developer Console 配置 App ID 启用 Sign in with Apple
    /// 3. 在 Supabase Dashboard 启用 Apple provider
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        isPerformingAppleSignIn = true

        defer { isPerformingAppleSignIn = false }

        do {
            // 1. 生成随机 nonce（raw nonce）
            // 这个 nonce 会被保存，稍后发送给 Supabase 进行验证
            let rawNonce = randomNonceString()
            currentNonce = rawNonce

            // 2. 计算 nonce 的 SHA256 哈希值（hashed nonce）
            // Apple 会将这个哈希值嵌入到返回的 identity token 中
            let hashedNonce = sha256(rawNonce)

            // 3. 创建 Apple ID 授权请求
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce  // 发送 hashed nonce 给 Apple

            // 4. 执行授权请求
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self

            // Guard against double-tap: if a continuation is already pending, bail out
            guard appleSignInContinuation == nil else {
                isLoading = false
                return
            }

            // Retain controller strongly so it survives until delegate callbacks fire.
            // A local variable would be deallocated after performRequests() returns,
            // silently cancelling the sheet before it appears.
            appleSignInController = controller

            // 使用 continuation 将回调转换为 async/await
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleSignInContinuation = continuation
                controller.performRequests()
            }

            appleSignInController = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
            debugLog("❌ Apple Sign-In error: \(error.localizedDescription)")
        }
    }

    /// Google 登录
    /// 使用 GoogleSignIn SDK 获取 OpenID Connect token，然后通过 Supabase 验证
    ///
    /// 配置步骤：
    /// 1. 在 Google Cloud Console 创建 OAuth 2.0 客户端 ID（iOS 类型）
    /// 2. 将 Client ID 填入 AppConfig.GoogleSignIn.clientId
    /// 3. 在 Info.plist 添加 URL Scheme（反转的 Client ID）
    /// 4. 在 Supabase Dashboard 启用 Google provider 并配置 Client ID/Secret
    func signInWithGoogle() async {
        // 检查是否已配置 Google Client ID
        guard AppConfig.GoogleSignIn.isConfigured else {
            errorMessage = NSLocalizedString("error_google_login_not_configured", comment: "")
            debugLog("⚠️ Google Sign-In: 请在 AppConfig.GoogleSignIn.clientId 中填入你的 Client ID")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 获取当前窗口的 rootViewController
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error_cannot_get_root_view_controller", comment: "")])
            }

            // 配置 Google Sign-In
            let config = GIDConfiguration(clientID: AppConfig.GoogleSignIn.clientId)
            GIDSignIn.sharedInstance.configuration = config

            // 执行 Google 登录
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            // 获取 ID Token（OpenID Connect token）
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error_cannot_get_google_token", comment: "")])
            }

            // 使用 Supabase 验证 Google token
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            currentUser = session.user
            isAuthenticated = true
            debugLog("✅ Google 登录成功: \(session.user.email ?? "unknown")")

            isLoading = false
        } catch {
            isLoading = false
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                errorMessage = NSLocalizedString("auth_user_cancelled_login", comment: "")
            } else {
                errorMessage = mapAuthError(error)
            }
            debugLog("❌ Google Sign-In error: \(error.localizedDescription)")
        }
    }

    // MARK: - ==================== 其他方法 ====================

    /// 删除账户
    /// 调用 Supabase Edge Function 删除用户账户
    /// - Note: 此操作不可逆，会永久删除用户数据
    func deleteAccount() async throws {
        debugLog("🗑️ [删除账户] 开始删除账户流程")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的 access token
            debugLog("🗑️ [删除账户] 正在获取当前会话...")
            let session = try await supabase.auth.session
            debugLog("🗑️ [删除账户] 会话获取成功，用户ID: \(session.user.id)")

            // 调用 delete-account Edge Function
            debugLog("🗑️ [删除账户] 正在调用 delete-account 边缘函数...")
            try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )

            debugLog("🗑️ [删除账户] 边缘函数调用成功，正在清除本地状态...")
            // 删除成功，清除本地状态
            handleSessionExpired()
            isLoading = false
            debugLog("✅ [删除账户] 账户删除完成，用户已登出")
        } catch {
            isLoading = false
            let errorMsg = mapAuthError(error)
            errorMessage = errorMsg
            debugLog("❌ [删除账户] 删除失败: \(error.localizedDescription)")
            debugLog("❌ [删除账户] 错误详情: \(error)")
            throw error
        }
    }

    /// 退出登录
    /// 调用 Supabase 登出接口，清空本地状态
    /// 登出后 isAuthenticated 会变为 false，RootView 会自动切换到登录页
    func signOut() async {
        isLoading = true

        do {
            try await supabase.auth.signOut()
            // 注意：signOut 成功后会触发 authStateChanges 的 .signedOut 事件
            // handleSessionExpired() 会在那里被调用，重置所有状态
            isLoading = false
        } catch {
            isLoading = false
            // 即使 API 调用失败，也强制清除本地状态
            // 这样用户可以重新登录
            handleSessionExpired()
            errorMessage = NSLocalizedString("error_logout_failed_session_cleared", comment: "")
            debugLog("❌ Sign out error: \(error.localizedDescription)")
        }
    }
    
    /// 强制退出登录（用于UI导航）
    /// 立即重置认证状态，不依赖网络请求
    @MainActor
    func forceSignOut() {
        debugLog("🔐 [AuthManager] Force sign out called")
        debugLog("🔐 [AuthManager] Current isAuthenticated: \(isAuthenticated)")
        
        handleSessionExpired()
        
        debugLog("🔐 [AuthManager] After handleSessionExpired, isAuthenticated: \(isAuthenticated)")
        
        // 同时尝试清除 Supabase 会话（异步，不等待结果）
        Task { [weak self] in
            do {
                try await supabase.auth.signOut()
                debugLog("🔐 [AuthManager] Background signOut succeeded")
            } catch {
                debugLog("🔐 [AuthManager] Background signOut failed: \(error.localizedDescription)")
            }
            _ = self // suppress unused capture warning; self is singleton
        }
    }

    /// 检查当前会话
    /// - Note: 用于应用启动时检查用户是否已登录
    func checkSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 如果有会话且不在密码设置流程中，则认为已认证
            if !needsPasswordSetup {
                isAuthenticated = true
            }
        } catch {
            // 没有会话，用户未登录
            currentUser = nil
            isAuthenticated = false
        }

        isLoading = false
    }

    /// 重置流程状态
    /// - Note: 用于用户取消流程时重置状态
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - ==================== 私有辅助方法 ====================

    /// 生成随机 nonce 字符串
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Return a UUID-based fallback nonce instead of crashing
            return UUID().uuidString + UUID().uuidString
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    /// SHA256 哈希
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    /// 错误信息映射
    /// - Parameter error: 原始错误
    /// - Returns: 用户友好的错误信息
    private func mapAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        if errorString.contains("Invalid login credentials") {
            return NSLocalizedString("error_email_or_password_incorrect", comment: "")
        } else if errorString.contains("Email not confirmed") {
            return NSLocalizedString("error_please_verify_email_first", comment: "")
        } else if errorString.contains("User already registered") {
            return NSLocalizedString("error_email_already_registered", comment: "")
        } else if errorString.contains("Password should be at least") || errorString.contains("weak_password") || errorString.contains("422") {
            // 422 Unprocessable Entity: Supabase server-side password policy rejection.
            // Also catches GoTrue "Password should be at least N chars" and "weak_password" codes.
            return NSLocalizedString("auth_password_too_weak", comment: "")
        } else if errorString.contains("Invalid email") {
            return NSLocalizedString("error_invalid_email_format", comment: "")
        } else if errorString.contains("Token has expired") || errorString.contains("otp_expired") {
            return NSLocalizedString("error_verification_code_expired", comment: "")
        } else if errorString.contains("Invalid OTP") || errorString.contains("invalid") && errorString.contains("otp") {
            return NSLocalizedString("error_verification_code_incorrect", comment: "")
        } else if errorString.contains("Email rate limit exceeded") {
            return NSLocalizedString("error_email_sent_too_frequently", comment: "")
        } else if errorString.contains("network") || errorString.contains("NSURLErrorDomain") {
            return NSLocalizedString("error_network_connection_failed", comment: "")
        } else if errorString.contains("canceled") || errorString.contains("1001") {
            return NSLocalizedString("error_user_cancelled", comment: "")
        } else if errorString.contains("For security purposes") {
            return NSLocalizedString("error_operation_too_frequent", comment: "")
        }

        return String(format: NSLocalizedString("error_operation_failed_format", comment: ""), error.localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use MainActor.assumeIsolated to safely access main actor state synchronously
        MainActor.assumeIsolated {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
            
            // Fallback: get any key window or create one with a window scene
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                return UIWindow(windowScene: windowScene)
            }
            
            // Last resort fallback (shouldn't happen in normal circumstances)
            fatalError("Unable to find a window scene for presentation")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ [AppleSignIn] didCompleteWithAuthorization — credential type: \(type(of: authorization.credential))")
        Task { @MainActor [weak self] in
            await self?.handleAppleAuthorization(authorization)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        print("❌ [AppleSignIn] didCompleteWithError — domain: \(nsError.domain)  code: \(nsError.code)  description: \(nsError.localizedDescription)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            appleSignInController = nil
            // User cancelled (code 1001) — don't show an error banner
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                print("ℹ️ [AppleSignIn] User cancelled — no error shown")
                isLoading = false
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }
            // All other errors — surface to UI
            errorMessage = nsError.localizedDescription
            isLoading = false
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
        }
    }

    /// 处理 Apple 授权结果
    private func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        print("🔐 [AppleSignIn] handleAppleAuthorization — extracting credentials...")
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            print("❌ [AppleSignIn] Failed to extract identity token or nonce")
            let error = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error_cannot_get_apple_credentials", comment: "")])
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
            return
        }

        print("🔐 [AppleSignIn] Token extracted — calling Supabase signInWithIdToken...")
        do {
            // 使用 Supabase 进行 Apple 登录
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: nonce
                )
            )
            debugLog("✅ [AppleSignIn] Supabase sign-in SUCCESS — user: \(session.user.email ?? session.user.id.uuidString)")
            currentUser = session.user
            isAuthenticated = true

            // 更新用户名（如果是首次登录）
            if let fullName = appleIDCredential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !displayName.isEmpty {
                    _ = try? await supabase.auth.update(user: UserAttributes(data: ["username": .string(displayName)]))
                }
            }

            appleSignInContinuation?.resume()
        } catch {
            print("❌ [AppleSignIn] Supabase signInWithIdToken FAILED — \(error.localizedDescription)")
            errorMessage = mapAuthError(error)
            appleSignInContinuation?.resume(throwing: error)
        }

        appleSignInController = nil
        appleSignInContinuation = nil
    }
}
