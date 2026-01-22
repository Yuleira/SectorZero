//
//  BuildingModels.swift
//  EarthLord
//
//  Core data models for the Building System.
//

import Foundation
import SwiftUI

enum BuildingCategory: String, Codable, CaseIterable {
    case survival
    case storage
    case production
    case energy

    var displayName: String {
        switch self {
        case .survival:
            return "Survival"
        case .storage:
            return "Storage"
        case .production:
            return "Production"
        case .energy:
            return "Energy"
        }
    }

    var iconName: String {
        switch self {
        case .survival:
            return "house.fill"
        case .storage:
            return "archivebox.fill"
        case .production:
            return "hammer.fill"
        case .energy:
            return "bolt.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .survival:
            return .orange
        case .storage:
            return .brown
        case .production:
            return .indigo
        case .energy:
            return .yellow
        }
    }
}

enum BuildingStatus: String, Codable {
    case constructing
    case active

    var displayName: String {
        switch self {
        case .constructing:
            return "Constructing"
        case .active:
            return "Active"
        }
    }

    var accentColor: Color {
        switch self {
        case .constructing:
            return .cyan
        case .active:
            return .green
        }
    }
}

struct BuildingTemplate: Identifiable, Codable {
    let id: UUID
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

struct PlayerBuilding: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
    }
}

enum BuildingError: Error {
    case insufficientResources(missing: [String: Int])
    case maxBuildingsReached(maxAllowed: Int)
    case invalidStatus
    case templateNotFound
}
