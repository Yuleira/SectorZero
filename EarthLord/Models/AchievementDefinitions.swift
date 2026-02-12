//
//  AchievementDefinitions.swift
//  EarthLord
//
//  Achievement model + 10 achievement definitions
//

import SwiftUI

enum AchievementCategory: String, CaseIterable {
    case exploration, building, survival

    var localizedName: LocalizedStringResource {
        switch self {
        case .exploration: return LocalizedString.achievementCategoryExploration
        case .building: return LocalizedString.achievementCategoryBuilding
        case .survival: return LocalizedString.achievementCategorySurvival
        }
    }

    var icon: String {
        switch self {
        case .exploration: return "map"
        case .building: return "building.2"
        case .survival: return "heart"
        }
    }
}

struct AchievementContext {
    let territoryCount: Int
    let totalArea: Double
    let totalDistance: Double
    let buildingCount: Int
    let itemCount: Int
    let daysSurvived: Int
    let discoveredPOICount: Int
}

struct Achievement: Identifiable {
    let id: String
    let name: LocalizedStringResource
    let description: LocalizedStringResource
    let icon: String
    let category: AchievementCategory
    let requirement: Int
    let progressProvider: (AchievementContext) -> Int

    func currentProgress(context: AchievementContext) -> Int {
        progressProvider(context)
    }

    func isUnlocked(context: AchievementContext) -> Bool {
        currentProgress(context: context) >= requirement
    }

    func progressFraction(context: AchievementContext) -> Double {
        guard requirement > 0 else { return 0 }
        return min(1.0, Double(currentProgress(context: context)) / Double(requirement))
    }
}

enum AchievementDefinitions {
    static let all: [Achievement] = [
        Achievement(
            id: "first_territory",
            name: LocalizedString.achievementFirstClaimName,
            description: LocalizedString.achievementFirstClaimDesc,
            icon: "flag.fill",
            category: .exploration,
            requirement: 1,
            progressProvider: { $0.territoryCount }
        ),
        Achievement(
            id: "territory_5",
            name: LocalizedString.achievementLandBaronName,
            description: LocalizedString.achievementLandBaronDesc,
            icon: "flag.2.crossed.fill",
            category: .exploration,
            requirement: 5,
            progressProvider: { $0.territoryCount }
        ),
        Achievement(
            id: "walk_1km",
            name: LocalizedString.achievementFirstStepsName,
            description: LocalizedString.achievementFirstStepsDesc,
            icon: "figure.walk",
            category: .exploration,
            requirement: 1000,
            progressProvider: { Int($0.totalDistance) }
        ),
        Achievement(
            id: "walk_10km",
            name: LocalizedString.achievementMarathonName,
            description: LocalizedString.achievementMarathonDesc,
            icon: "figure.run",
            category: .exploration,
            requirement: 10000,
            progressProvider: { Int($0.totalDistance) }
        ),
        Achievement(
            id: "area_10k",
            name: LocalizedString.achievementTerritoryLordName,
            description: LocalizedString.achievementTerritoryLordDesc,
            icon: "map.fill",
            category: .exploration,
            requirement: 10000,
            progressProvider: { Int($0.totalArea) }
        ),
        Achievement(
            id: "first_building",
            name: LocalizedString.achievementConstructorName,
            description: LocalizedString.achievementConstructorDesc,
            icon: "hammer.fill",
            category: .building,
            requirement: 1,
            progressProvider: { $0.buildingCount }
        ),
        Achievement(
            id: "buildings_10",
            name: LocalizedString.achievementArchitectName,
            description: LocalizedString.achievementArchitectDesc,
            icon: "building.2.fill",
            category: .building,
            requirement: 10,
            progressProvider: { $0.buildingCount }
        ),
        Achievement(
            id: "poi_5",
            name: LocalizedString.achievementScoutName,
            description: LocalizedString.achievementScoutDesc,
            icon: "binoculars.fill",
            category: .exploration,
            requirement: 5,
            progressProvider: { $0.discoveredPOICount }
        ),
        Achievement(
            id: "survive_7",
            name: LocalizedString.achievementWeekSurvivorName,
            description: LocalizedString.achievementWeekSurvivorDesc,
            icon: "calendar",
            category: .survival,
            requirement: 7,
            progressProvider: { $0.daysSurvived }
        ),
        Achievement(
            id: "survive_30",
            name: LocalizedString.achievementVeteranName,
            description: LocalizedString.achievementVeteranDesc,
            icon: "medal.fill",
            category: .survival,
            requirement: 30,
            progressProvider: { $0.daysSurvived }
        ),
    ]
}
