//
//  AchievementsView.swift
//  EarthLord
//
//  Achievements tab UI with progress ring, category filter, unlock status
//

import SwiftUI
import Supabase
internal import Auth

struct AchievementsView: View {

    @ObservedObject private var territoryManager = TerritoryManager.shared
    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var selectedCategory: AchievementCategory?
    @State private var showUnlockedOnly = false
    @State private var discoveredPOICount = 0

    private var context: AchievementContext {
        AchievementContext(
            territoryCount: territoryManager.territories.count,
            totalArea: territoryManager.territories.reduce(0) { $0 + $1.area },
            totalDistance: territoryManager.totalDistanceWalked,
            buildingCount: buildingManager.playerBuildings.count,
            itemCount: inventoryManager.items.count,
            daysSurvived: daysSurvived,
            discoveredPOICount: discoveredPOICount
        )
    }

    private var filteredAchievements: [Achievement] {
        var list = AchievementDefinitions.all
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if showUnlockedOnly {
            list = list.filter { $0.isUnlocked(context: context) }
        }
        return list
    }

    private var unlockedCount: Int {
        AchievementDefinitions.all.filter { $0.isUnlocked(context: context) }.count
    }

    private var totalCount: Int {
        AchievementDefinitions.all.count
    }

    var body: some View {
        VStack(spacing: 16) {
            progressCard
            categoryFilter
            unlockedToggle

            if filteredAchievements.isEmpty {
                emptyState
            } else {
                achievementList
            }
        }
        .task {
            await fetchPOICount()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        HStack(spacing: 20) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: totalCount > 0 ? CGFloat(unlockedCount) / CGFloat(totalCount) : 0)
                    .stroke(ApocalypseTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text("\(totalCount > 0 ? Int(Double(unlockedCount) / Double(totalCount) * 100) : 0)%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.achievementProgress)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.success)
                        Text("\(unlockedCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(LocalizedString.achievementUnlocked)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text("\(totalCount - unlockedCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(LocalizedString.achievementLocked)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: LocalizedString.achievementCategoryAll, icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(AchievementCategory.allCases, id: \.self) { cat in
                    categoryChip(label: cat.localizedName, icon: cat.icon, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
        }
    }

    private func categoryChip(label: LocalizedStringResource, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - Toggle

    private var unlockedToggle: some View {
        Toggle(isOn: $showUnlockedOnly) {
            Text(LocalizedString.achievementShowUnlocked)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.primary))
        .padding(.horizontal, 4)
    }

    // MARK: - Achievement List

    private var achievementList: some View {
        VStack(spacing: 8) {
            ForEach(filteredAchievements) { achievement in
                achievementRow(achievement)
            }
        }
    }

    private func achievementRow(_ achievement: Achievement) -> some View {
        let unlocked = achievement.isUnlocked(context: context)
        let progress = achievement.progressFraction(context: context)

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(unlocked ? ApocalypseTheme.primary.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.body)
                    .foregroundColor(unlocked ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            }

            // Name + Description + Progress
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(unlocked ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(unlocked ? ApocalypseTheme.success : ApocalypseTheme.primary)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer(minLength: 0)

            // Badge
            if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(ApocalypseTheme.success)
            } else {
                Text("\(achievement.currentProgress(context: context))/\(achievement.requirement)")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.title)
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(LocalizedString.achievementEmpty)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var daysSurvived: Int {
        guard let created = authManager.currentUser?.createdAt else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 0)
    }

    private func fetchPOICount() async {
        guard let userId = SupabaseService.shared.client.auth.currentUser?.id else { return }
        do {
            let count: Int = try await SupabaseService.shared.client
                .from("pois")
                .select("*", head: true, count: .exact)
                .eq("discovered_by", value: userId)
                .execute()
                .count ?? 0
            discoveredPOICount = count
        } catch {
            print("⚠️ [Achievements] Failed to fetch POI count: \(error)")
        }
    }
}
