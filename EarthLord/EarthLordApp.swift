//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Yu Lei on 23/12/2025.
//

import SwiftUI
import GoogleSignIn
import UIKit

@main
struct EarthLordApp: App {

    /// Language manager for locale injection at root level
    @StateObject private var languageManager = LanguageManager.shared

    /// Scene phase for background/foreground lifecycle
    @Environment(\.scenePhase) private var scenePhase

    /// Background task identifier to keep app alive during claiming/exploration
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init() {
        // Validate configuration (DEBUG only)
        AppConfig.validateConfiguration()
        // Start StoreKit 2 transaction listener at launch (for real-device IAP)
        _ = StoreKitManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Late-Binding Localization: inject locale at the very root
                .environment(\.locale, languageManager.currentLocale)
                .id(languageManager.refreshID)
                // Google Sign-In URL callback
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - Background Lifecycle

    /// Handle app going to background/foreground during active claiming or exploration
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        let isClaiming = LocationManager.shared.isTracking
        let isExploring = ExplorationManager.shared.isExploring

        switch phase {
        case .background:
            if isClaiming || isExploring {
                debugLog("🔄 [App生命周期] 进入后台 — 活跃任务进行中，请求后台执行时间")
                beginBackgroundTask()
            }
        case .active:
            debugLog("🔄 [App生命周期] 回到前台")
            endBackgroundTask()
            // Re-enable background tracking if still claiming/exploring
            if isClaiming || isExploring {
                LocationManager.shared.enableBackgroundTracking()
                // Re-arm location updates if the OS paused them during background
                if !LocationManager.shared.isUpdatingLocation {
                    LocationManager.shared.startUpdatingLocation()
                }
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Request background execution time from iOS to prevent suspension
    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ActiveClaiming") {
            // Expiration handler — iOS is about to kill us, clean up
            // Apple 文档：expiration handler 在主线程调用，所以用 assumeIsolated 安全且同步
            MainActor.assumeIsolated {
                debugLog("🔄 [App生命周期] ⚠️ 后台执行时间即将耗尽")
                ExplorationManager.shared.cancelExploration()
                LocationManager.shared.stopPathTracking()
                self.endBackgroundTask()
            }
        }
        debugLog("🔄 [App生命周期] 后台任务已启动 (id: \(backgroundTaskID.rawValue))")
    }

    /// End background task when no longer needed
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        debugLog("🔄 [App生命周期] 后台任务已结束 (id: \(backgroundTaskID.rawValue))")
        backgroundTaskID = .invalid
    }
}

/// Root container view — auth/main → onboarding (first-run)
struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authManager.isInitializing {
                // 等待 Supabase 初始会话检查，显示主题启动画面而非黑屏
                LaunchPlaceholderView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isInitializing)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onAppear {
            #if DEBUG
            print("🏠 [ContentView] Locale: \(LanguageManager.shared.currentLocale.identifier)")
            #endif
        }
        .onChange(of: authManager.isInitializing) { _, initializing in
            // 初始化完成后，已登录且是新用户 → 显示 onboarding
            if !initializing && authManager.isAuthenticated && !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // 登录后，新用户 → 显示 onboarding
            if isAuth && !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }
}

/// 启动占位画面 — 等待 Supabase 会话恢复期间显示，替代黑屏
private struct LaunchPlaceholderView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(ApocalypseTheme.primary)
                    .scaleEffect(pulse ? 1.1 : 0.95)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                Text("SectorZero")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(ApocalypseTheme.textPrimary)

                ProgressView()
                    .tint(ApocalypseTheme.primary)
            }
        }
        .onAppear { pulse = true }
    }
}
