//
//  RootView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI

/// 根视图：控制启动页、登录页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器
    private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isLoading {
                // 加载中
                loadingView
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // 已登录 -> 主界面
                MainTabView()
                    .transition(.opacity)
            } else {
                // 未登录 -> 登录页
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.isLoading)
    }

    // MARK: - 加载视图
    private var loadingView: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("加载中...")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    RootView()
}
