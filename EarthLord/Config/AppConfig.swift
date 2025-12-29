//
//  AppConfig.swift
//  EarthLord
//
//  Created by Yu Lei on 29/12/2025.
//

import Foundation

// ============================================================================
// 📋 第三方登录配置指南
// ============================================================================
//
// 🍎 Apple Sign-In 配置步骤：
// ────────────────────────────────────────────────────────────────────────────
// 1. Xcode 项目配置：
//    - 打开项目 → Signing & Capabilities → + Capability → "Sign in with Apple"
//
// 2. Apple Developer Console (https://developer.apple.com):
//    - Certificates, Identifiers & Profiles → Identifiers
//    - 选择你的 App ID → 确保 "Sign in with Apple" 已启用
//
// 3. Supabase Dashboard (https://supabase.com/dashboard):
//    - Authentication → Providers → Apple → 启用
//    - 填入 Service ID、Team ID、Key ID、Private Key（如需 Web 登录）
//    - iOS 原生登录只需启用 Provider 即可，无需额外配置
//
// 🔍 Google Sign-In 配置步骤：
// ────────────────────────────────────────────────────────────────────────────
// 1. Google Cloud Console (https://console.cloud.google.com):
//    - APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client IDs
//    - 选择 "iOS" 类型
//    - 填入 Bundle ID: com.yourcompany.EarthLord
//    - 下载配置或复制 Client ID
//
// 2. 安装 GoogleSignIn SDK：
//    - Xcode → File → Add Package Dependencies
//    - 输入: https://github.com/google/GoogleSignIn-iOS
//    - 选择版本并添加
//
// 3. Info.plist 配置 URL Scheme：
//    - 添加 URL Types:
//      <key>CFBundleURLTypes</key>
//      <array>
//        <dict>
//          <key>CFBundleURLSchemes</key>
//          <array>
//            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
//          </array>
//        </dict>
//      </array>
//    - 注意：URL Scheme 是 Client ID 的反转形式
//
// 4. Supabase Dashboard:
//    - Authentication → Providers → Google → 启用
//    - 填入 Client ID 和 Client Secret（从 Google Cloud Console 获取）
//
// 5. 代码启用：
//    - 取消 AuthManager.swift 中 "import GoogleSignIn" 的注释
//    - 取消 signInWithGoogle() 方法中的实现代码注释
//    - 取消 EarthLordApp.swift 中的 GoogleSignIn 相关注释
//
// ============================================================================

/// 应用配置管理
/// 集中管理所有第三方服务的配置信息
enum AppConfig {

    // MARK: - ==================== Supabase 配置 ====================

    enum Supabase {
        /// Supabase 项目 URL
        static let projectURL = "https://zkcjvhdhartrrekzjtjg.supabase.co"

        /// Supabase 公开 API Key（可安全暴露在客户端）
        static let publishableKey = "sb_publishable_uVzbdyBvBhzQi9WV3uOlBA_GWGGrR07"
    }

    // MARK: - ==================== Apple 登录配置 ====================

    enum AppleSignIn {
        /// Apple Services ID（用于 Supabase 回调）
        /// 在 Apple Developer Console 创建 Services ID 后填入
        /// 格式示例: com.yourcompany.earthlord.auth
        static let servicesId = ""

        /// 是否已配置（检查是否填入了有效值）
        static var isConfigured: Bool {
            !servicesId.isEmpty
        }
    }

    // MARK: - ==================== Google 登录配置 ====================

    enum GoogleSignIn {
        /// Google OAuth Client ID（iOS 客户端）
        /// 在 Google Cloud Console 创建 OAuth 2.0 客户端 ID 后填入
        /// 格式示例: 123456789-abcdef.apps.googleusercontent.com
        static let clientId = "122441609812-r7ujmpln8lp338e68pff4vg44jjs8v4u.apps.googleusercontent.com"

        /// 反转的 Client ID（用于 URL Scheme）
        /// 将 clientId 的各部分反转，用于 Info.plist 配置
        /// 格式示例: com.googleusercontent.apps.123456789-abcdef
        static var reversedClientId: String {
            guard !clientId.isEmpty else { return "" }
            // 将 xxx.apps.googleusercontent.com 转换为 com.googleusercontent.apps.xxx
            let components = clientId.split(separator: ".").reversed()
            return components.joined(separator: ".")
        }

        /// 是否已配置（检查是否填入了有效值）
        static var isConfigured: Bool {
            !clientId.isEmpty
        }
    }

    // MARK: - ==================== 功能开关 ====================

    enum Features {
        /// 是否启用 Apple 登录
        /// 注意：还需要在 Xcode 中添加 "Sign in with Apple" capability
        static let enableAppleSignIn = true

        /// 是否启用 Google 登录
        /// 注意：需要安装 GoogleSignIn SDK 并配置 URL Scheme
        static let enableGoogleSignIn = true
    }
}

// MARK: - ==================== 配置验证 ====================

extension AppConfig {

    /// 检查所有必需的配置是否已完成
    static func validateConfiguration() {
        #if DEBUG
        print("🔧 === 配置检查 ===")
        print("📦 Supabase URL: \(Supabase.projectURL)")
        print("🍎 Apple Sign-In: \(AppleSignIn.isConfigured ? "已配置 ✅" : "未配置 ⚠️")")
        print("🔍 Google Sign-In: \(GoogleSignIn.isConfigured ? "已配置 ✅" : "未配置 ⚠️")")

        if Features.enableGoogleSignIn && !GoogleSignIn.isConfigured {
            print("⚠️ 警告: Google 登录已启用但未配置 Client ID")
            print("   请在 AppConfig.GoogleSignIn.clientId 中填入你的 Client ID")
        }

        if Features.enableAppleSignIn {
            print("ℹ️ 提示: 请确保已在 Xcode 的 Signing & Capabilities 中添加 'Sign in with Apple'")
        }
        print("🔧 ==================")
        #endif
    }
}
