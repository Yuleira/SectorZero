//
//  SupabaseService.swift
//  EarthLord
//
//  Supabase客户端单例服务
//  为整个应用提供统一的Supabase客户端访问
//

import Foundation
import Supabase

/// Supabase客户端单例服务
final class SupabaseService {

    // MARK: - Singleton

    static let shared = SupabaseService()

    // MARK: - Properties

    /// Supabase客户端实例
    let client: SupabaseClient

    // MARK: - Initialization

    private init() {
        // 初始化Supabase客户端
        self.client = SupabaseClient(
            supabaseURL: URL(string: AppConfig.Supabase.projectURL)!,
            supabaseKey: AppConfig.Supabase.publishableKey,
            options: .init(
                db: .init(
                    schema: "public"
                ),
                auth: .init(
                    redirectToURL: URL(string: "earthlord://auth/callback"),
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(
                    logger: nil
                )
            )
        )

        // 验证配置
        if !Self.isConfigured() {
            debugLog("⚠️ [SupabaseService] Invalid configuration detected!")
            debugLog("   Please update AppConfig.Supabase with your project credentials")
        }

        debugLog("✅ [SupabaseService] Initialized")
        debugLog("   URL: \(AppConfig.Supabase.projectURL)")
    }

    // MARK: - Configuration Validation

    /// 验证 Supabase 配置是否有效（静态方法，可在不访问单例的情况下调用）
    static func isConfigured() -> Bool {
        let url = AppConfig.Supabase.projectURL
        let key = AppConfig.Supabase.publishableKey

        // 检查 URL 格式
        guard url.hasPrefix("https://") && url.contains(".supabase.co") else {
            return false
        }

        // 检查 URL 不是占位符
        guard !url.contains("YOUR_PROJECT_ID") else {
            return false
        }

        // 检查 Key 格式（真实的 Supabase anon key 以 eyJ 开头）
        guard key.count > 100 && key.hasPrefix("eyJ") else {
            return false
        }

        return true
    }

    /// 实例方法：验证配置（用于初始化时）
    private func validateConfiguration() -> Bool {
        Self.isConfigured()
    }
}

/// 全局Supabase客户端便捷访问
let supabase = SupabaseService.shared.client
