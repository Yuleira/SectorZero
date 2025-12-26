//
//  AuthManager.swift
//  EarthLord
//
//  Created by Yu Lei on 26/12/2025.
//

import Foundation
import Supabase
import Observation
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager: NSObject {
    static let shared = AuthManager()

    private(set) var currentUser: User?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    // Apple 登录用
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    private var authStateTask: Task<Void, Never>?

    private override init() {
        super.init()
        setupAuthStateListener()
    }

    // MARK: - 设置认证状态监听
    private func setupAuthStateListener() {
        authStateTask = Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    // 初始会话
                    self.currentUser = session?.user
                    self.isLoading = false
                case .signedIn:
                    // 登录成功
                    self.currentUser = session?.user
                    self.isLoading = false
                case .signedOut:
                    // 退出登录
                    self.currentUser = nil
                    self.isLoading = false
                case .userUpdated:
                    // 用户信息更新
                    self.currentUser = session?.user
                case .tokenRefreshed:
                    // Token 刷新
                    self.currentUser = session?.user
                default:
                    break
                }
            }
        }
    }

    // MARK: - 检查当前会话（手动调用）
    @MainActor
    func checkSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }

        isLoading = false
    }

    // MARK: - 邮箱注册
    @MainActor
    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["username": .string(username)]
            )
            currentUser = response.user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - 邮箱登录
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - 退出登录
    @MainActor
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            currentUser = nil
        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Apple 登录
    @MainActor
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // 生成 nonce
            let nonce = randomNonceString()
            currentNonce = nonce

            // 创建 Apple ID 请求
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            // 执行授权
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleSignInContinuation = continuation
                controller.performRequests()
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    // MARK: - 生成随机 nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    // MARK: - SHA256 哈希
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    // MARK: - 错误映射
    private func mapAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        if errorString.contains("Invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("Email not confirmed") {
            return "请先验证邮箱"
        } else if errorString.contains("User already registered") {
            return "该邮箱已注册"
        } else if errorString.contains("Password should be at least") {
            return "密码至少需要6个字符"
        } else if errorString.contains("Invalid email") {
            return "邮箱格式不正确"
        } else if errorString.contains("network") || errorString.contains("NSURLErrorDomain") {
            return "网络连接失败，请检查网络"
        } else if errorString.contains("canceled") || errorString.contains("1001") {
            return "用户取消了登录"
        }

        return "操作失败: \(error.localizedDescription)"
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            let error = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取 Apple 登录凭证"])
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
            return
        }

        // 使用 Supabase 进行 Apple 登录
        Task { @MainActor in
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken,
                        nonce: nonce
                    )
                )
                currentUser = session.user

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
                errorMessage = mapAuthError(error)
                appleSignInContinuation?.resume(throwing: error)
            }
            appleSignInContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
    }
}
