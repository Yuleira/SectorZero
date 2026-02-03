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

            StoreView()
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text(LocalizedString.tabStore)
                }
                .tag(4)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(LocalizedString.tabProfile)
                }
                .tag(5)

        }
        .tint(ApocalypseTheme.primary)
        .id(languageManager.refreshID)
        .onAppear {
            // 用户登录后启动位置追踪
            if authManager.isAuthenticated {
                PlayerPresenceManager.shared.startPresenceTracking()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // 监听登录状态变化
            if isAuthenticated {
                PlayerPresenceManager.shared.startPresenceTracking()
            } else {
                PlayerPresenceManager.shared.stopPresenceTracking()
            }
        }
    }
}

#Preview {
    MainTabView()
}
