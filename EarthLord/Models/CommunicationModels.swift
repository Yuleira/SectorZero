//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  支持多种通讯设备：收音机、对讲机、营地电台、卫星通讯
//

import Foundation

// MARK: - 设备类型

/// 通讯设备类型
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    /// 显示名称（本地化）
    var displayName: String {
        switch self {
        case .radio: return String(localized: "device_radio")
        case .walkieTalkie: return String(localized: "device_walkie_talkie")
        case .campRadio: return String(localized: "device_base_station")
        case .satellite: return String(localized: "device_satellite")
        }
    }

    /// SF Symbol 图标名称
    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "flipphone"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    /// 设备描述（本地化）
    var description: String {
        switch self {
        case .radio: return String(localized: "desc_receive_only")
        case .walkieTalkie: return String(format: String(localized: "desc_comm_range_format"), 3)
        case .campRadio: return String(format: String(localized: "desc_broadcast_range_format"), 30)
        case .satellite: return String(format: String(localized: "desc_contact_range_format"), 100)
        }
    }

    /// 通讯范围（公里）
    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    /// 范围文字描述（本地化）
    var rangeText: String {
        switch self {
        case .radio: return String(localized: "range_unlimited_receive_only")
        case .walkieTalkie: return String(format: String(localized: "range_format"), 3)
        case .campRadio: return String(format: String(localized: "range_format"), 30)
        case .satellite: return String(format: String(localized: "range_format"), 100) + "+"
        }
    }

    /// 是否可以发送消息
    var canSend: Bool {
        self != .radio
    }

    /// 解锁条件说明（本地化）
    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return String(localized: "unlock_default_owned")
        case .campRadio: return String(localized: "unlock_require_base_station")
        case .satellite: return String(localized: "unlock_require_comm_tower")
        }
    }
}

// MARK: - 设备模型

/// 通讯设备数据模型
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举

/// 通讯系统导航区块
enum CommunicationSection: String, CaseIterable {
    case messages
    case channels
    case call
    case devices

    /// 显示名称（本地化）
    var displayName: String {
        switch self {
        case .messages: return String(localized: "nav_messages")
        case .channels: return String(localized: "nav_channels")
        case .call: return String(localized: "nav_calls")
        case .devices: return String(localized: "nav_devices")
        }
    }

    /// SF Symbol 图标名称
    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型

/// 通讯频道类型
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case publicChannel = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    /// 显示名称（本地化）
    var displayName: String {
        switch self {
        case .official: return String(localized: LocalizedString.channelTypeOfficial)
        case .publicChannel: return String(localized: LocalizedString.channelTypePublic)
        case .walkie: return String(localized: LocalizedString.channelTypeWalkie)
        case .camp: return String(localized: LocalizedString.channelTypeCamp)
        case .satellite: return String(localized: LocalizedString.channelTypeSatellite)
        }
    }

    /// SF Symbol 图标名称
    var iconName: String {
        switch self {
        case .official: return "megaphone.fill"
        case .publicChannel: return "globe"
        case .walkie: return "flipphone"
        case .camp: return "tent.fill"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    /// 频道类型描述（本地化）
    var description: String {
        switch self {
        case .official: return String(localized: LocalizedString.channelDescOfficial)
        case .publicChannel: return String(localized: LocalizedString.channelDescPublic)
        case .walkie: return String(localized: LocalizedString.channelDescWalkie)
        case .camp: return String(localized: LocalizedString.channelDescCamp)
        case .satellite: return String(localized: LocalizedString.channelDescSatellite)
        }
    }

    /// 频道码前缀
    var codePrefix: String {
        switch self {
        case .official: return "OFF-"
        case .publicChannel: return "PUB-"
        case .walkie: return "438."
        case .camp: return "CAMP-"
        case .satellite: return "SAT-"
        }
    }

    /// 用户是否可以创建此类型频道
    var isUserCreatable: Bool {
        switch self {
        case .official: return false
        case .publicChannel, .walkie, .camp, .satellite: return true
        }
    }

    /// 用户可创建的频道类型
    static var userCreatableTypes: [ChannelType] {
        allCases.filter { $0.isUserCreatable }
    }
}

// MARK: - 频道模型

/// 通讯频道数据模型
struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 频道订阅模型

/// 频道订阅数据模型
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道组合模型

/// 已订阅频道（组合频道与订阅信息）
struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - Message System Models (Day 34)

/// Location point model for PostGIS POINT parsing
struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    /// Parse from PostGIS WKT format: POINT(longitude latitude)
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

/// Message metadata
struct MessageMetadata: Codable {
    let deviceType: String?

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
    }
}

/// Channel message model
struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let metadata: MessageMetadata?
    let createdAt: Date

    // Day 35-C: Numerical coordinates (bypass PostGIS hex parsing)
    let senderLatitude: Double?
    let senderLongitude: Double?

    var id: UUID { messageId }

    /// Computed LocationPoint from numerical coordinates
    var senderLocation: LocationPoint? {
        guard let lat = senderLatitude, let lon = senderLongitude else {
            return nil
        }
        return LocationPoint(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case metadata
        case createdAt = "created_at"
        case senderLatitude = "sender_latitude"
        case senderLongitude = "sender_longitude"
    }

    // Custom decoder for numerical coordinates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // Day 35-C: Direct numerical coordinate parsing (NO PostGIS)
        senderLatitude = try container.decodeIfPresent(Double.self, forKey: .senderLatitude)
        senderLongitude = try container.decodeIfPresent(Double.self, forKey: .senderLongitude)

        // VERIFICATION LOG - Remove after testing
        if let lat = senderLatitude, let lon = senderLongitude {
            print("[Decoder] ✅ NUMERICAL COORDS: lat=\(lat), lon=\(lon)")
        } else {
            print("[Decoder] ⚠️ NO NUMERICAL COORDS - will use Conservative Strategy")
        }

        // Parse date (multiple formats support)
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    // Multi-format date parser
    private static func parseDate(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    /// Time ago display
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return String(localized: LocalizedString.messageJustNow)
        } else if interval < 3600 {
            return String(format: String(localized: LocalizedString.messageMinutesAgoFormat), Int(interval / 60))
        } else if interval < 86400 {
            return String(format: String(localized: LocalizedString.messageHoursAgoFormat), Int(interval / 3600))
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    /// Device type from metadata
    var deviceType: String? {
        metadata?.deviceType
    }

    /// Sender device type (parsed from metadata)
    var senderDeviceType: DeviceType? {
        guard let deviceTypeString = metadata?.deviceType else { return nil }
        return DeviceType(rawValue: deviceTypeString)
    }
}
