//
//  MainTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text(LocalizedString.tabMap)
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text(LocalizedString.tabTerritory)
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text(LocalizedString.tabResources)
                }
                .tag(2)

            CommunicationTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text(LocalizedString.communication)
                }
                .tag(3)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text(LocalizedString.tabPersonal)
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
        .id(languageManager.refreshID)
        .onAppear(perform: onSessionStart)
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                PlayerPresenceManager.shared.startPresenceTracking()
                Task { await StoreKitManager.shared.loadEntitlementsFromSupabase() }
            } else {
                PlayerPresenceManager.shared.stopPresenceTracking()
            }
        }
    }

    // MARK: - Session Lifecycle

    private func onSessionStart() {
        guard authManager.isAuthenticated else { return }
        PlayerPresenceManager.shared.startPresenceTracking()
        Task {
            await StoreKitManager.shared.loadEntitlementsFromSupabase()
        }
    }
}

#Preview {
    MainTabView()
}
