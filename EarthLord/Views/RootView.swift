//
//  RootView.swift
//  EarthLord
//
//  根视图 - 处理认证状态切换
//  根据用户登录状态显示主界面或登录界面
//

import SwiftUI

/// 根视图
/// 负责根据认证状态切换主界面和登录界面
struct RootView: View {
    
    // MARK: - 状态属性
    
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared
    
    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared
    
    // MARK: - 视图
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // 已登录：显示主界面
                MainTabView()
            } else {
                // 未登录：显示登录界面
                AuthView()
            }
        }
        .id(languageManager.refreshID) // 支持语言切换刷新
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}