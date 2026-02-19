//
//  LeaderboardManager.swift
//  EarthLord
//
//  Supabase leaderboard queries
//

import Foundation
import Combine
import Supabase

enum LeaderboardCategory: String, CaseIterable {
    case territoryArea = "territory_area"
    case poiCount = "poi_count"
    case buildingCount = "building_count"

    var localizedName: LocalizedStringResource {
        switch self {
        case .territoryArea: return LocalizedString.leaderboardCategoryTerritory
        case .poiCount: return LocalizedString.leaderboardCategoryPOI
        case .buildingCount: return LocalizedString.leaderboardCategoryBuilding
        }
    }

    var icon: String {
        switch self {
        case .territoryArea: return "map"
        case .poiCount: return "location.fill"
        case .buildingCount: return "building.2"
        }
    }

    var unit: String {
        switch self {
        case .territoryArea: return "m²"
        case .poiCount: return ""
        case .buildingCount: return ""
        }
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: UUID
    let username: String
    let score: Double
    let totalPlayers: Int

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case username
        case score
        case totalPlayers = "total_players"
    }
}

@MainActor
final class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()

    @Published var entries: [LeaderboardEntry] = []
    @Published var currentUserEntry: LeaderboardEntry?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {}

    func fetchLeaderboard(category: LeaderboardCategory, timePeriod: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [LeaderboardEntry] = try await SupabaseService.shared.client
                .rpc(
                    "get_leaderboard",
                    params: [
                        "p_category": AnyJSON.string(category.rawValue),
                        "p_time_period": AnyJSON.string(timePeriod),
                        "p_limit": AnyJSON.integer(50)
                    ]
                )
                .execute()
                .value

            entries = response

            if let currentUserId = SupabaseService.shared.client.auth.currentUser?.id {
                currentUserEntry = entries.first { $0.userId == currentUserId }
            }
        } catch {
            errorMessage = error.localizedDescription
            debugLog("❌ [Leaderboard] Failed to fetch: \(error)")
        }

        isLoading = false
    }
}
