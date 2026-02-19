//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Yu Lei on 24/12/2025.
//

import SwiftUI
import Supabase

/// 个人页面 — Survivor Command Center
/// 数据丰富的仪表盘：身份卡、操作按钮、统计面板
struct ProfileTabView: View {

    // MARK: - Enums

    enum DashboardTab: String, CaseIterable {
        case statistics, leaderboard, achievements, vitals

        var localizedName: LocalizedStringResource {
            switch self {
            case .statistics: return LocalizedString.profileStatistics
            case .leaderboard: return LocalizedString.profileLeaderboard
            case .achievements: return LocalizedString.profileAchievements
            case .vitals: return LocalizedString.profileVitals
            }
        }
    }

    enum TimePeriod: String, CaseIterable {
        case today, thisWeek, thisMonth, allTime

        var localizedName: LocalizedStringResource {
            switch self {
            case .today: return LocalizedString.profileToday
            case .thisWeek: return LocalizedString.profileThisWeek
            case .thisMonth: return LocalizedString.profileThisMonth
            case .allTime: return LocalizedString.profileAllTime
            }
        }
    }

    // MARK: - State & Observers

    @ObservedObject private var authManager = AuthManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var territoryManager = TerritoryManager.shared
    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var storeKitManager = StoreKitManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var explorationManager = ExplorationManager.shared

    @State private var selectedDashboardTab: DashboardTab = .statistics
    @State private var selectedTimePeriod: TimePeriod = .thisWeek
    @State private var showTerritorySheet = false
    @State private var showBackpackSheet = false
    @State private var showPOISheet = false
    @State private var showDetailedStatsSheet = false

    // DB-backed exploration stats
    @State private var explorationSessionCount: Int = 0
    @State private var explorationTotalDistance: Double = 0
    @State private var explorationTotalItems: Int = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    identityCard
                    vaultSection
                    dataDashboard
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedString.profileSurvivorTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .id(languageManager.refreshID)
            .task {
                let _ = try? await territoryManager.loadMyTerritories()
                await buildingManager.fetchPlayerBuildings()
                await inventoryManager.loadItems()
                await storeKitManager.loadEntitlementsFromSupabase()
                await refreshExplorationStats()
            }
            .onAppear {
                Task {
                    await territoryManager.loadTotalDistanceWalked()
                }
            }
            .onChange(of: selectedTimePeriod) { _, _ in
                Task { await refreshExplorationStats() }
            }
            .sheet(isPresented: $showTerritorySheet) {
                sheetWrapper { TerritoryTabView() }
            }
            .sheet(isPresented: $showBackpackSheet) {
                sheetWrapper { BackpackView() }
            }
            .sheet(isPresented: $showPOISheet) {
                sheetWrapper { POIListView() }
            }
            .sheet(isPresented: $showDetailedStatsSheet) {
                DetailedStatisticsSheet()
            }
        }
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .stroke(Color(.systemGray3).opacity(0.4), lineWidth: 3)
                    .frame(width: 126, height: 126)

                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.8))
                    .frame(width: 120, height: 120)

                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)

            // Username
            Text(username)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Tier Badge
            NavigationLink(destination: StoreView(initialSection: .subscriptions)) {
                Text(storeKitManager.currentMembershipTier.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                    )
            }

            if storeKitManager.currentMembershipTier != .free,
               let text = storeKitManager.formattedExpirationDate {
                Text(text)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // Stats Row with dividers
            HStack(spacing: 0) {
                Button { showTerritorySheet = true } label: {
                    identityStat(
                        icon: "mappin.and.ellipse",
                        value: "\(territoryCount)",
                        label: LocalizedString.profileStatTerritories
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 40)
                    .overlay(Color.gray.opacity(0.4))

                identityStat(
                    icon: "calendar",
                    value: "\(daysSurvived)Days",
                    label: LocalizedString.profileDaysSurvival
                )

                Divider()
                    .frame(height: 40)
                    .overlay(Color.gray.opacity(0.4))

                Button { showTerritorySheet = true } label: {
                    identityStat(
                        icon: "building.2.fill",
                        value: "\(buildingCount)",
                        label: LocalizedString.profileStatBuildingsCount
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func identityStat(icon: String, value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .frame(height: 20)
                .foregroundColor(.blue)
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vault Section

    private var vaultSection: some View {
        VStack(spacing: 10) {
            // Row 1: Subscription + Energy side by side
            HStack(spacing: 10) {
                subscriptionButton
                    .frame(maxHeight: .infinity)
                aetherEnergyCard
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)

            // Row 2: Storage card (full width)
            NavigationLink(destination: BackpackView()) {
                storageCard
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Subscription Button

    private var subscriptionButton: some View {
        NavigationLink(destination: StoreView(initialSection: .subscriptions)) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.callout)
                Text(LocalizedString.profileViewSubscription)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Aether Energy Card

    private var aetherEnergyCard: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedString.vaultAetherEnergy)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if storeKitManager.isInfiniteEnergyEnabled {
                    Text(LocalizedString.vaultUnlimited)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Text("\(storeKitManager.aetherEnergy)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            Spacer(minLength: 0)

            NavigationLink(destination: StoreView(initialSection: .energy)) {
                Text(LocalizedString.vaultBuyMore)
                    .font(.system(size: 10))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.yellow)
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Storage Card

    private var storageCard: some View {
        let usage = inventoryManager.currentUsage
        let limit = storeKitManager.currentStorageLimit
        let progress = limit > 0 ? Double(usage) / Double(limit) : 0
        let isFull = usage >= limit

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill((isFull ? ApocalypseTheme.danger : ApocalypseTheme.info).opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "archivebox.fill")
                        .font(.callout)
                        .foregroundColor(isFull ? ApocalypseTheme.danger : ApocalypseTheme.info)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedString.vaultStorage)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                    Text("\(usage) / \(limit)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isFull ? ApocalypseTheme.danger : Color(red: 1.0, green: 0.4, blue: 0.2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 0)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isFull ? ApocalypseTheme.danger : ApocalypseTheme.info)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)

            if isFull {
                Text(LocalizedString.vaultStorageFull)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Data Dashboard

    private var dataDashboard: some View {
        VStack(spacing: 16) {
            // Dashboard Tab Picker
            dashboardTabPicker

            // Content based on selected tab
            switch selectedDashboardTab {
            case .statistics:
                statisticsContent
            case .leaderboard:
                LeaderboardView()
            case .achievements:
                AchievementsView()
            case .vitals:
                VitalsView()
            }
        }
        .padding(16)
    }

    // MARK: - Dashboard Tab Picker

    private var dashboardTabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDashboardTab = tab
                    }
                } label: {
                    Text(tab.localizedName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedDashboardTab == tab ? .white : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selectedDashboardTab == tab
                                ? Capsule().fill(ApocalypseTheme.primary)
                                : Capsule().fill(Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Statistics Content

    private var statisticsContent: some View {
        VStack(spacing: 16) {
            // Time Period Picker
            timePeriodPicker

            // Stat Cards Grid
            statCardsGrid

            // View Detailed Stats button
            Button {
                showDetailedStatsSheet = true
            } label: {
                HStack {
                    Text(LocalizedString.profileViewDetailedStats)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Time Period Picker

    private var timePeriodPicker: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimePeriod = period
                    }
                } label: {
                    Text(period.localizedName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTimePeriod == period ? .white : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedTimePeriod == period
                                ? Capsule().fill(ApocalypseTheme.primary)
                                : Capsule().fill(Color.clear)
                        )
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Stat Cards Grid

    private var statCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            Button { showTerritorySheet = true } label: {
                statCard(
                    icon: "figure.walk",
                    iconColor: .blue,
                    value: formattedTotalDistance,
                    label: LocalizedString.profileStatDistance
                )
            }
            .buttonStyle(.plain)

            Button { showTerritorySheet = true } label: {
                statCard(
                    icon: "map",
                    iconColor: .green,
                    value: formattedArea,
                    label: LocalizedString.profileStatArea
                )
            }
            .buttonStyle(.plain)

            Button { showBackpackSheet = true } label: {
                statCard(
                    icon: "flame",
                    iconColor: .orange,
                    value: "\(resourceCount)",
                    label: LocalizedString.profileStatResources
                )
            }
            .buttonStyle(.plain)

            Button { showPOISheet = true } label: {
                statCard(
                    icon: "mappin.circle",
                    iconColor: .purple,
                    value: "\(poiCount)",
                    label: LocalizedString.profileStatPOI
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func statCard(icon: String, iconColor: Color, value: String, label: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon in colored rounded square
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(iconColor)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.2))
                )

            // Value
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Label
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Computed Properties

    private var username: String {
        if let name = authManager.currentUser?.userMetadata["username"]?.stringValue, !name.isEmpty {
            return name
        }
        if let email = authManager.currentUser?.email,
           let prefix = email.split(separator: "@").first {
            return String(prefix)
        }
        return String(localized: "profile_default_username")
    }

    private var email: String {
        authManager.currentUser?.email ?? String(localized: "profile_no_email")
    }

    private var avatarUrl: String? {
        authManager.currentUser?.userMetadata["avatar_url"]?.stringValue
    }

    private var daysSurvived: Int {
        guard let created = authManager.currentUser?.createdAt else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0)
    }

    private var territoryCount: Int { territoryManager.territories.count }

    private var buildingCount: Int { buildingManager.playerBuildings.count }

    private var poiCount: Int { explorationTotalItems }

    private var totalArea: Double { territoryManager.territories.reduce(0) { $0 + $1.area } }

    private var resourceCount: Int { inventoryManager.items.count }

    private var formattedArea: String {
        if totalArea >= 1_000_000 { return String(format: "%.2f km²", totalArea / 1_000_000) }
        return String(format: "%.0f m²", totalArea)
    }

    private var formattedTotalDistance: String {
        // Use time-filtered exploration stats when not "all time"
        let d: Double
        if selectedTimePeriod == .allTime {
            d = territoryManager.totalDistanceWalked
        } else {
            d = explorationTotalDistance
        }
        if d >= 1000 { return String(format: "%.2f km", d / 1000) }
        return String(format: "%.0f m", d)
    }

    // MARK: - Exploration Stats

    private func refreshExplorationStats() async {
        let since = sinceDate(for: selectedTimePeriod)
        let stats = await explorationManager.loadExplorationStats(since: since)
        explorationSessionCount = stats.sessions
        explorationTotalDistance = stats.totalDistance
        explorationTotalItems = stats.totalItems
    }

    private func sinceDate(for period: TimePeriod) -> Date? {
        let calendar = Calendar.current
        switch period {
        case .today:
            return calendar.startOfDay(for: Date())
        case .thisWeek:
            return calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date
        case .thisMonth:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
        case .allTime:
            return nil
        }
    }

    // MARK: - Helpers

    private func sheetWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .topTrailing) {
                Button {
                    showTerritorySheet = false
                    showBackpackSheet = false
                    showPOISheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.gray.opacity(0.5))
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
            }
    }

    private func tierColor(for tier: MembershipTier) -> Color {
        switch tier {
        case .free: return ApocalypseTheme.textSecondary
        case .scavenger: return Color.brown
        case .pioneer: return Color.gray
        case .archon: return Color.yellow
        }
    }
}

// MARK: - 删除账户确认视图
struct DeleteAccountConfirmView: View {
    @Binding var isPresented: Bool
    var onError: (String) -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var confirmText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var requiredText: String { String(localized: "profile_delete_confirm_required_text") }

    private var canDelete: Bool {
        confirmText == requiredText
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 40)

                Text(LocalizedString.profileConfirmDeleteAccount)
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    Text(LocalizedString.profileDeleteIrreversible)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Text(LocalizedString.profileDeleteDataWarning)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(LocalizedString.profileDeleteItemProfile, systemImage: "person.crop.circle")
                        Label(LocalizedString.profileDeleteItemProgress, systemImage: "gamecontroller")
                        Label(LocalizedString.profileDeleteItemAuth, systemImage: "key")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: String(localized: "profile_delete_confirm_prompt %@"), requiredText))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField(String(format: String(localized: "profile_delete_confirm_placeholder %@"), requiredText), text: $confirmText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task {
                            do {
                                try await authManager.deleteAccount()
                                isPresented = false
                            } catch {
                                onError(authManager.errorMessage ?? String(localized: "profile_delete_error"))
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(LocalizedString.profileConfirmDelete)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canDelete ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete || authManager.isLoading)

                    Button {
                        isPresented = false
                    } label: {
                        Text(LocalizedString.commonCancel)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                debugLog("📱 [删除账户] 显示删除确认页面")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 语言设置视图
struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if languageManager.selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } footer: {
                Text(LocalizedString.profileLanguageUpdateNote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(LocalizedString.profileLanguageSettings)
        .navigationBarTitleDisplayMode(.inline)
        .id(languageManager.refreshID)
    }
}

#Preview {
    ProfileTabView()
}
