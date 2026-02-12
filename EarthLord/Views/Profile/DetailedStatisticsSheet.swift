//
//  DetailedStatisticsSheet.swift
//  EarthLord
//
//  Sheet with exploration/activity/resource stat breakdowns
//

import SwiftUI
internal import Auth

struct DetailedStatisticsSheet: View {

    @ObservedObject private var territoryManager = TerritoryManager.shared
    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var storeKitManager = StoreKitManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    explorationSection
                    activitySection
                    resourceSection
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedString.detailedStatsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Exploration Stats

    private var explorationSection: some View {
        statsSection(
            icon: "binoculars",
            iconColor: .blue,
            title: LocalizedString.detailedStatsExploration
        ) {
            statRow(label: LocalizedString.detailedStatsDistance, value: formattedDistance)
            statRow(label: LocalizedString.detailedStatsArea, value: formattedArea)
            statRow(label: LocalizedString.detailedStatsTerritories, value: "\(territoryManager.territories.count)")
            statRow(label: LocalizedString.detailedStatsPOIs, value: "\(ExplorationManager.shared.nearbyPOIs.count)")
        }
    }

    // MARK: - Activity Stats

    private var activitySection: some View {
        statsSection(
            icon: "figure.walk",
            iconColor: .green,
            title: LocalizedString.detailedStatsActivity
        ) {
            statRow(label: LocalizedString.detailedStatsCalories, value: "0 kcal")
            statRow(label: LocalizedString.detailedStatsGameTime, value: "\(daysSurvived) days")
            statRow(label: LocalizedString.detailedStatsSteps, value: "-")
            statRow(label: LocalizedString.detailedStatsActiveDays, value: "-")
        }
    }

    // MARK: - Resource Stats

    private var resourceSection: some View {
        statsSection(
            icon: "cube.box",
            iconColor: .orange,
            title: LocalizedString.detailedStatsResources
        ) {
            statRow(label: LocalizedString.detailedStatsItems, value: "\(inventoryManager.items.count)")
            statRow(label: LocalizedString.detailedStatsBuildings, value: "\(buildingManager.playerBuildings.count)")
            statRow(label: LocalizedString.detailedStatsStorage, value: "\(inventoryManager.currentUsage)/\(storeKitManager.currentStorageLimit)")
        }
    }

    // MARK: - Helpers

    private func statsSection<Content: View>(
        icon: String,
        iconColor: Color,
        title: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(iconColor)
                    .padding(6)
                    .background(iconColor.opacity(0.2))
                    .cornerRadius(8)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                content()
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func statRow(label: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.vertical, 8)
    }

    private var daysSurvived: Int {
        guard let created = authManager.currentUser?.createdAt else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0)
    }

    private var formattedDistance: String {
        let d = territoryManager.totalDistanceWalked
        if d >= 1000 { return String(format: "%.2f km", d / 1000) }
        return String(format: "%.0f m", d)
    }

    private var formattedArea: String {
        let area = territoryManager.territories.reduce(0) { $0 + $1.area }
        if area >= 1_000_000 { return String(format: "%.2f km²", area / 1_000_000) }
        return String(format: "%.0f m²", area)
    }
}
