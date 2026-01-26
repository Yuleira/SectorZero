import Foundation
import SwiftUI

// MARK: - 物品品质（影响物品状态/耐久度）

enum ItemQuality: String, Codable, CaseIterable {
    case pristine = "pristine"
    case good = "good"
    case worn = "worn"
    case damaged = "damaged"
    case ruined = "ruined"

    /// 本地化显示名称 (Late-Binding: evaluated at render time)
    var localizedName: LocalizedStringResource {
        switch self {
        case .pristine: return "quality_pristine"
        case .good: return "quality_good"
        case .worn: return "quality_worn"
        case .damaged: return "quality_damaged"
        case .ruined: return "quality_ruined"
        }
    }

    var color: Color {
        switch self {
        case .pristine: return .purple
        case .good: return .blue
        case .worn: return .green
        case .damaged: return .orange
        case .ruined: return .gray
        }
    }
}

// MARK: - 物品稀有度（决定掉落概率和价值）

/// 物品稀有度（独立于品质 ItemQuality）
/// - common: 普通物品，最常见
/// - uncommon: 优秀物品，比普通好一些
/// - rare: 稀有物品，有一定价值
/// - epic: 史诗物品，非常珍贵
/// - legendary: 传奇物品，极其罕见
enum ItemRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"

    /// 本地化显示名称 (Late-Binding: evaluated at render time)
    var localizedName: LocalizedStringResource {
        switch self {
        case .common: return "rarity_common"
        case .uncommon: return "rarity_uncommon"
        case .rare: return "rarity_rare"
        case .epic: return "rarity_epic"
        case .legendary: return "rarity_legendary"
        }
    }

    /// 对应的显示颜色
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 背景渐变色（用于卡片展示）
    var gradientColors: [Color] {
        switch self {
        case .common: return [Color.gray.opacity(0.3), Color.gray.opacity(0.1)]
        case .uncommon: return [Color.green.opacity(0.3), Color.mint.opacity(0.1)]
        case .rare: return [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)]
        case .epic: return [Color.purple.opacity(0.4), Color.pink.opacity(0.2)]
        case .legendary: return [Color.orange.opacity(0.4), Color.yellow.opacity(0.2)]
        }
    }
}

// MARK: - 物品分类

enum ItemCategory: String, Codable, CaseIterable {
    case water = "water"
    case food = "food"
    case medical = "medical"
    case material = "material"
    case tool = "tool"
    case weapon = "weapon"
    case other = "other"

    /// 本地化显示名称 (Late-Binding: evaluated at render time)
    var localizedName: LocalizedStringResource {
        switch self {
        case .water: return "category_water"
        case .food: return "category_food"
        case .medical: return "category_medical"
        case .material: return "category_material"
        case .tool: return "category_tool"
        case .weapon: return "category_weapon"
        case .other: return "category_other"
        }
    }
}

// MARK: - 物品定义

struct ItemDefinition: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: ItemCategory
    let icon: String
    let rarity: ItemRarity

    /// 向后兼容的初始化器（默认稀有度为普通）
    init(id: String, name: String, description: String, category: ItemCategory, icon: String, rarity: ItemRarity = .common) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.rarity = rarity
    }

    // MARK: - Localization Support (Late-Binding)

    /// 本地化名称（Late-Binding: 在渲染时使用String Catalog解析）
    var localizedName: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(name))
    }

    /// 本地化描述（Late-Binding）
    var localizedDescription: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(description))
    }

    /// 已解析的本地化名称（用于字符串插值和数据库操作）
    var resolvedLocalizedName: String {
        let locale = LanguageManager.shared.currentLocale
        return String(localized: String.LocalizationValue(name), locale: locale)
    }

    /// 已解析的本地化描述（用于字符串插值）
    var resolvedLocalizedDescription: String {
        let locale = LanguageManager.shared.currentLocale
        return String(localized: String.LocalizationValue(description), locale: locale)
    }
}

struct CollectedItem: Identifiable, Codable {
    let id: UUID
    let definition: ItemDefinition
    let quality: ItemQuality
    let foundDate: Date
    var quantity: Int = 1

    // MARK: - AI Generated Item Properties

    /// AI 生成的独特物品名称（覆盖 definition.name）
    var aiName: String?

    /// AI 生成的背景故事
    var aiStory: String?

    /// 是否为 AI 生成的物品
    var isAIGenerated: Bool = false

    /// 显示名称（Late-Binding: 优先使用 AI 名称）
    /// AI 名称不需要本地化（用户生成），定义名称需要本地化
    var displayName: LocalizedStringResource {
        if let aiName = aiName {
            // AI-generated name: return as string literal (no localization)
            return LocalizedStringResource(stringLiteral: aiName)
        } else {
            // Definition name: return localized resource
            return definition.localizedName
        }
    }

    /// 物品 ID，让 View 能找到它
    var itemId: String {
        return definition.id
    }

    init(
        id: UUID = UUID(),
        definition: ItemDefinition,
        quality: ItemQuality,
        foundDate: Date = Date(),
        quantity: Int = 1,
        aiName: String? = nil,
        aiStory: String? = nil,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.definition = definition
        self.quality = quality
        self.foundDate = foundDate
        self.quantity = quantity
        self.aiName = aiName
        self.aiStory = aiStory
        self.isAIGenerated = isAIGenerated
    }
}
