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

    @State private var selectedDashboardTab: DashboardTab = .statistics
    @State private var selectedTimePeriod: TimePeriod = .thisWeek

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    identityCard
                    dataDashboard
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedString.profileSurvivorTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .id(languageManager.refreshID)
            .task {
                let _ = try? await territoryManager.loadMyTerritories()
                await buildingManager.fetchPlayerBuildings()
                await inventoryManager.loadItems()
            }
        }
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .stroke(ApocalypseTheme.primary, lineWidth: 3)
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Membership Badge
            Text(storeKitManager.currentMembershipTier.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(tierColor(for: storeKitManager.currentMembershipTier))
                )

            if storeKitManager.currentMembershipTier != .free,
               let text = storeKitManager.formattedExpirationDate {
                Text(text)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // Summary Stats Row
            summaryStatsRow

            // Action Buttons Grid
            actionButtonsGrid
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Summary Stats Row

    private var summaryStatsRow: some View {
        HStack(spacing: 0) {
            summaryStatColumn(
                icon: "calendar",
                value: "\(daysSurvived)",
                label: LocalizedString.profileDaysSurvival
            )

            // Divider
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(width: 1, height: 50)

            summaryStatColumn(
                icon: "shield.fill",
                value: "\(territoryCount)",
                label: LocalizedString.profileStatTerritories
            )

            // Divider
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(width: 1, height: 50)

            summaryStatColumn(
                icon: "building.2.fill",
                value: "\(buildingCount)",
                label: LocalizedString.profileStatBuildingsCount
            )
        }
        .padding(.vertical, 12)
    }

    private func summaryStatColumn(icon: String, value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons Row

    private var actionButtonsGrid: some View {
        HStack(spacing: 10) {
            // Edit Profile → Settings (profile editing)
            NavigationLink {
                ProfileSettingsView()
            } label: {
                actionButtonLabel(
                    icon: "pencil",
                    title: LocalizedString.profileEditProfile,
                    background: AnyShapeStyle(ApocalypseTheme.cardBackground)
                )
            }

            // Settings
            NavigationLink {
                ProfileSettingsView()
            } label: {
                actionButtonLabel(
                    icon: "gearshape",
                    title: LocalizedString.profileSettings,
                    background: AnyShapeStyle(ApocalypseTheme.cardBackground)
                )
            }
        }
    }

    private func actionButtonLabel(icon: String, title: LocalizedStringResource, background: AnyShapeStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.bold())
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.subheadline.bold())
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(background)
        .cornerRadius(12)
    }

    // MARK: - Data Dashboard

    private var dataDashboard: some View {
        VStack(spacing: 16) {
            // Dashboard Tab Picker
            dashboardTabPicker

            // Content based on selected tab
            if selectedDashboardTab == .statistics {
                statisticsContent
            } else {
                comingSoonPlaceholder
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
            // Section Title
            VStack(spacing: 4) {
                Text(LocalizedString.profileStatistics)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(LocalizedString.profileDataDriven)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Time Period Picker
            timePeriodPicker

            // Stat Cards Grid
            statCardsGrid
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
            statCard(
                icon: "figure.walk",
                iconColor: .blue,
                value: "0 m",
                label: LocalizedString.profileStatDistance
            )

            statCard(
                icon: "map",
                iconColor: .green,
                value: formattedArea,
                label: LocalizedString.profileStatArea
            )

            statCard(
                icon: "flame",
                iconColor: .orange,
                value: "\(resourceCount)",
                label: LocalizedString.profileStatResources
            )

            statCard(
                icon: "building.2",
                iconColor: .purple,
                value: "\(buildingCount)",
                label: LocalizedString.profileStatBuildingsCount
            )
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

    // MARK: - Coming Soon Placeholder

    private var comingSoonPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(LocalizedString.profileComingSoon)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

    private var totalArea: Double { territoryManager.territories.reduce(0) { $0 + $1.area } }

    private var resourceCount: Int { inventoryManager.items.count }

    private var formattedArea: String {
        if totalArea >= 1_000_000 { return String(format: "%.2f km²", totalArea / 1_000_000) }
        return String(format: "%.0f m²", totalArea)
    }

    // MARK: - Helpers

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
                print("📱 [删除账户] 显示删除确认页面")
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
