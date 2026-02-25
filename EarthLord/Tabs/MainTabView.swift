//
//  MainTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//
//  Adaptive layout:
//  - iPad (.regular horizontalSizeClass): NavigationSplitView with sidebar
//  - iPhone (.compact): standard TabView (unchanged behaviour)
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    // Adaptive layout switch
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPhone tab selection (Int tag, preserves existing behaviour)
    @State private var selectedTab = 0

    // iPad sidebar selection (optional so List can deselect)
    @State private var selectedSplitTab: SplitTab? = .map

    // MARK: - SplitTab (iPad sidebar items)

    enum SplitTab: Int, CaseIterable, Identifiable {
        case map = 0, territory, resources, communications, profile
        var id: Int { rawValue }

        var icon: String {
            switch self {
            case .map:            return "map.fill"
            case .territory:      return "flag.fill"
            case .resources:      return "cube.box.fill"
            case .communications: return "antenna.radiowaves.left.and.right"
            case .profile:        return "person.circle.fill"
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .map:            return LocalizedString.tabMap
            case .territory:      return LocalizedString.tabTerritory
            case .resources:      return LocalizedString.tabResources
            case .communications: return LocalizedString.communication
            case .profile:        return LocalizedString.tabPersonal
            }
        }
    }

    // MARK: - Body

    var body: some View {
        if horizontalSizeClass == .regular {
            ipadLayout
        } else {
            phoneLayout
        }
    }

    // MARK: - iPhone Layout (original TabView, unchanged)

    private var phoneLayout: some View {
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
                WatchConnectivityManager.shared.activate()
                Task { await StoreKitManager.shared.loadEntitlementsFromSupabase() }
            } else {
                PlayerPresenceManager.shared.stopPresenceTracking()
            }
        }
    }

    // MARK: - iPad Layout (NavigationSplitView sidebar)

    private var ipadLayout: some View {
        NavigationSplitView {
            List(SplitTab.allCases, selection: $selectedSplitTab) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.icon)
                }
                .tag(tab)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(ApocalypseTheme.background)
            .navigationTitle("SectorZero")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(ApocalypseTheme.primary)
        } detail: {
            ipadDetailView
        }
        .navigationSplitViewStyle(.balanced)
        .id(languageManager.refreshID)
        .onAppear(perform: onSessionStart)
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                PlayerPresenceManager.shared.startPresenceTracking()
                WatchConnectivityManager.shared.activate()
                Task { await StoreKitManager.shared.loadEntitlementsFromSupabase() }
            } else {
                PlayerPresenceManager.shared.stopPresenceTracking()
            }
        }
    }

    @ViewBuilder
    private var ipadDetailView: some View {
        switch selectedSplitTab ?? .map {
        case .map:            MapTabView()
        case .territory:      TerritoryTabView()
        case .resources:      ResourcesTabView()
        case .communications: CommunicationTabView()
        case .profile:        ProfileTabView()
        }
    }

    // MARK: - Session Lifecycle

    private func onSessionStart() {
        guard authManager.isAuthenticated else { return }
        PlayerPresenceManager.shared.startPresenceTracking()
        WatchConnectivityManager.shared.activate()
        Task {
            await StoreKitManager.shared.loadEntitlementsFromSupabase()
        }
    }
}

#Preview {
    MainTabView()
}
