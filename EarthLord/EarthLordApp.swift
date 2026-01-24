//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {

    init() {
        // Step 1A：清空历史语言缓存
        UserDefaults.standard.removeObject(forKey: "app_language")
        // 验证配置（仅在 DEBUG 模式下输出）
        AppConfig.validateConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Google Sign-In URL 回调处理
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

/// 应用根容器视图 - 认证状态驱动的导航
struct ContentView: View {
    /// 认证管理器 - 观察认证状态变化
    @ObservedObject private var authManager = AuthManager.shared
    
    /// 语言管理器 - 支持语言切换
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // 已认证：显示主应用界面
                MainTabView()
            } else {
                // 未认证：显示登录界面
                AuthView()
            }
        }
    // --- 🚀 重新加回来的关键代码 ---
            .environment(\.locale, languageManager.currentLocale) // 1. 注入语言环境，让 String(localized:) 生效
            .id(languageManager.refreshID) // 2. 切换语言时强制刷新整个视图树
            // ----------------------------
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .onAppear {
                print("🏠 [ContentView] Current Locale: \(languageManager.currentLocale.identifier)")
        }
    }
}
