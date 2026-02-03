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
    
    /// Language manager for locale injection at root level
    @StateObject private var languageManager = LanguageManager.shared

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
    }
}

/// Root container view - authentication-driven navigation
struct ContentView: View {
    /// Authentication manager - observe auth state changes
    @ObservedObject private var authManager = AuthManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Authenticated: show main app
                MainTabView()
            } else {
                // Not authenticated: show login
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        #if DEBUG
        .onAppear {
            print("🏠 [ContentView] Locale: \(LanguageManager.shared.currentLocale.identifier)")
        }
        #endif
    }
}
