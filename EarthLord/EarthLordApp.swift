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
/// 这是认证导航的单一真相来源
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
                    .onAppear {
                        print("🏠 [ContentView] Showing MainTabView (authenticated)")
                    }
            } else {
                // 未认证：显示登录界面
                AuthView()
                    .onAppear {
                        print("🏠 [ContentView] Showing AuthView (not authenticated)")
                    }
            }
        }
        .id(languageManager.refreshID) // 支持语言切换时刷新
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            print("🏠 [ContentView] Auth state changed: \(oldValue) → \(newValue)")
        }
        .onAppear {
            print("🏠 [ContentView] Initial auth state: \(authManager.isAuthenticated)")
        }
    }
}
