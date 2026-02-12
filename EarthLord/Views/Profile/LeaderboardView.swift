//
//  LeaderboardView.swift
//  EarthLord
//
//  Leaderboard tab UI with category picker, time filter, rankings
//

import SwiftUI

struct LeaderboardView: View {

    @StateObject private var leaderboardManager = LeaderboardManager.shared
    @State private var selectedCategory: LeaderboardCategory = .territoryArea
    @State private var selectedTimePeriod: String = "all_time"

    private let timePeriods: [(key: String, label: LocalizedStringResource)] = [
        ("today", LocalizedString.profileToday),
        ("this_week", LocalizedString.profileThisWeek),
        ("all_time", LocalizedString.profileAllTime),
    ]

    var body: some View {
        VStack(spacing: 16) {
            categoryPicker
            timePeriodPicker
            myScoreCard
            playerList
        }
        .task {
            await leaderboardManager.fetchLeaderboard(category: selectedCategory, timePeriod: selectedTimePeriod)
        }
        .onChange(of: selectedCategory) {
            Task {
                await leaderboardManager.fetchLeaderboard(category: selectedCategory, timePeriod: selectedTimePeriod)
            }
        }
        .onChange(of: selectedTimePeriod) {
            Task {
                await leaderboardManager.fetchLeaderboard(category: selectedCategory, timePeriod: selectedTimePeriod)
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(LeaderboardCategory.allCases, id: \.self) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.callout)
                        Text(cat.localizedName)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(selectedCategory == cat ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedCategory == cat ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    // MARK: - Time Period Picker

    private var timePeriodPicker: some View {
        HStack(spacing: 4) {
            ForEach(timePeriods, id: \.key) { period in
                Button {
                    selectedTimePeriod = period.key
                } label: {
                    Text(period.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTimePeriod == period.key ? .white : ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimePeriod == period.key ? ApocalypseTheme.primary : Color.clear)
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

    // MARK: - My Score Card

    private var myScoreCard: some View {
        Group {
            if let entry = leaderboardManager.currentUserEntry {
                HStack(spacing: 16) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 50, height: 50)
                        Text("#\(entry.rank)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedString.leaderboardMyScore)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(formattedScore(entry.score))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if entry.totalPlayers > 0 {
                            let percentile = Double(entry.rank) / Double(entry.totalPlayers) * 100
                            Text(String(format: String(localized: "leaderboard_percentile_format"), percentile))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        Text(String(format: String(localized: "leaderboard_total_players_format"), entry.totalPlayers))
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(16)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Player List

    private var playerList: some View {
        Group {
            if leaderboardManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if leaderboardManager.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(LocalizedString.leaderboardNoData)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)
            } else {
                VStack(spacing: 4) {
                    ForEach(leaderboardManager.entries) { entry in
                        playerRow(entry)
                    }
                }
            }
        }
    }

    private func playerRow(_ entry: LeaderboardEntry) -> some View {
        let isTopThree = entry.rank <= 3
        let bgColor: Color = {
            switch entry.rank {
            case 1: return Color.yellow.opacity(0.1)
            case 2: return Color.gray.opacity(0.1)
            case 3: return Color.orange.opacity(0.1)
            default: return ApocalypseTheme.cardBackground
            }
        }()

        return HStack(spacing: 12) {
            // Rank
            if isTopThree {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(entry.rank == 1 ? .yellow : entry.rank == 2 ? .gray : .orange)
                    .frame(width: 28)
            } else {
                Text("#\(entry.rank)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 28)
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.3))
                    .frame(width: 32, height: 32)
                Text(String(entry.username.prefix(1)).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // Name
            Text(entry.username)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Score
            Text(formattedScore(entry.score))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(bgColor)
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private func formattedScore(_ score: Double) -> String {
        let unit = selectedCategory.unit
        if selectedCategory == .territoryArea {
            if score >= 1_000_000 {
                return String(format: "%.1f km²", score / 1_000_000)
            }
            return String(format: "%.0f %@", score, unit)
        }
        return "\(Int(score))"
    }
}
