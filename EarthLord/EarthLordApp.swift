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

/// App launch phase state machine
private enum LaunchPhase {
    case splash      // Playing cinematic video
    case mainApp     // Auth / Main tab visible
}

/// Root container view — splash → auth/main → onboarding (first-run)
struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var launchPhase: LaunchPhase = .splash
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            // Main app layer (always mounted so auth state listener runs)
            mainAppView
                .opacity(launchPhase == .mainApp ? 1 : 0)

            // Splash layer (on top, removed after fade)
            if launchPhase == .splash {
                SplashVideoView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        launchPhase = .mainApp
                    }
                    // Trigger onboarding after splash if authenticated + first run
                    if authManager.isAuthenticated && !hasCompletedOnboarding {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showOnboarding = true
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var mainAppView: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // Post-splash: if user logs in for the first time, show onboarding
            if isAuth && !hasCompletedOnboarding && launchPhase == .mainApp {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        #if DEBUG
        .onAppear {
            print("🏠 [ContentView] Locale: \(LanguageManager.shared.currentLocale.identifier)")
        }
        #endif
    }
}
