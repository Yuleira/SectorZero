//
//  LocalizedString.swift
//  EarthLord
//
//  集中管理的 UI 本地化 Key，对应 Localizable.xcstrings，
//  避免硬编码字符串，方便统一替换与补翻。
//
//  Late-Binding Localization Strategy:
//  所有UI文本使用LocalizedStringResource类型，在渲染时才解析为当前语言
//

import SwiftUI

/// 集中管理的本地化 Key（LocalizedStringResource）
/// 使用示例：
///   - Text(LocalizedString.unnamedTerritory)
///   - Text(String(format: String(localized: LocalizedString.builtFormat), current, max))
enum LocalizedString {

    // MARK: - Territory (11 keys)

    /// 未命名领地 (territory_unnamed)
    static let unnamedTerritory: LocalizedStringResource = "territory_unnamed"

    /// 我的领地标题 (territory_my_title)
    static let territoryMyTitle: LocalizedStringResource = "territory_my_title"

    /// 建筑列表标题 (territory_buildings)
    static let territoryBuildings: LocalizedStringResource = "territory_buildings"

    /// 没有建筑 (territory_no_buildings)
    static let territoryNoBuildings: LocalizedStringResource = "territory_no_buildings"

    /// 建造提示 (territory_build_hint)
    static let territoryBuildHint: LocalizedStringResource = "territory_build_hint"

    /// 重命名 (territory_rename)
    static let territoryRename: LocalizedStringResource = "territory_rename"

    /// 空状态标题 (territory_empty_title)
    static let territoryEmptyTitle: LocalizedStringResource = "territory_empty_title"

    /// 空状态描述 (territory_empty_description)
    static let territoryEmptyDescription: LocalizedStringResource = "territory_empty_description"

    /// 领地数量标签 (territory_count_label)
    static let territoryCountLabel: LocalizedStringResource = "territory_count_label"

    /// 总面积标签 (territory_total_area_label)
    static let territoryTotalAreaLabel: LocalizedStringResource = "territory_total_area_label"

    /// 登录提示 (territory_login_prompt)
    static let territoryLoginPrompt: LocalizedStringResource = "territory_login_prompt"

    /// 领地积分，格式串 "Territory Points %lld" (territory_points_format)
    /// 用法: String(format: String(localized: LocalizedString.territoryPointsFormat), count)
    static let territoryPointsFormat: LocalizedStringResource = "territory_points_format"

    /// Territory limit reached format (error_territory_limit_reached_format)
    static let errorTerritoryLimitReachedFormat: LocalizedStringResource = "error_territory_limit_reached_format"

    /// Territory overlap error (error_territory_overlap)
    static let errorTerritoryOverlap: LocalizedStringResource = "error_territory_overlap"

    /// 删除领地确认标题 (territory_delete_confirm_title)
    static let territoryDeleteConfirmTitle: LocalizedStringResource = "territory_delete_confirm_title"

    /// 删除领地确认消息 (territory_delete_confirm_message)
    static let territoryDeleteConfirmMessage: LocalizedStringResource = "territory_delete_confirm_message"

    // MARK: - Building (28 keys)

    /// 建造按钮 (building_build)
    static let buildingBuild: LocalizedStringResource = "building_build"

    /// 建筑浏览器标题 (building_browser_title)
    static let buildingBrowserTitle: LocalizedStringResource = "building_browser_title"

    /// 浏览器空状态 (building_browser_empty_title)
    static let buildingBrowserEmptyTitle: LocalizedStringResource = "building_browser_empty_title"

    /// 放置建筑标题 (building_place_title)
    static let buildingPlaceTitle: LocalizedStringResource = "building_place_title"

    /// 建造时间 (building_build_time)
    static let buildingBuildTime: LocalizedStringResource = "building_build_time"

    /// 每领地最大数量 (building_max_per_territory)
    static let buildingMaxPerTerritory: LocalizedStringResource = "building_max_per_territory"

    /// 资源充足 (building_resources_sufficient)
    static let buildingResourcesSufficient: LocalizedStringResource = "building_resources_sufficient"

    /// 选择位置 (building_select_location)
    static let buildingSelectLocation: LocalizedStringResource = "building_select_location"

    /// 位置已选择 (building_location_selected)
    static let buildingLocationSelected: LocalizedStringResource = "building_location_selected"

    /// 位置坐标 (building_location_coordinates)
    static let buildingLocationCoordinates: LocalizedStringResource = "building_location_coordinates"

    /// 点击选择位置 (building_tap_to_select_location)
    static let buildingTapToSelectLocation: LocalizedStringResource = "building_tap_to_select_location"

    /// 确认建造 (building_confirm_construction)
    static let buildingConfirmConstruction: LocalizedStringResource = "building_confirm_construction"

    /// 建造成功 (building_construction_success)
    static let buildingConstructionSuccess: LocalizedStringResource = "building_construction_success"

    /// 建造失败 (building_construction_failed)
    static let buildingConstructionFailed: LocalizedStringResource = "building_construction_failed"

    /// 点击放置 (building_tap_to_place)
    static let buildingTapToPlace: LocalizedStringResource = "building_tap_to_place"

    /// 确认位置 (building_confirm_location)
    static let buildingConfirmLocation: LocalizedStringResource = "building_confirm_location"

    /// 位置无效 (building_location_invalid)
    static let buildingLocationInvalid: LocalizedStringResource = "building_location_invalid"

    /// 已选位置 (building_selected_location)
    static let buildingSelectedLocation: LocalizedStringResource = "building_selected_location"

    /// 位置超出领地 (building_location_outside_territory)
    static let buildingLocationOutsideTerritory: LocalizedStringResource = "building_location_outside_territory"

    /// 升级 (building_upgrade)
    static let buildingUpgrade: LocalizedStringResource = "building_upgrade"

    /// 拆除 (building_demolish)
    static let buildingDemolish: LocalizedStringResource = "building_demolish"

    /// 拆除确认 (building_demolish_confirm)
    static let buildingDemolishConfirm: LocalizedStringResource = "building_demolish_confirm"

    /// 资源不足 (building_resources_insufficient)
    static let insufficientResources: LocalizedStringResource = "building_resources_insufficient"

    /// 已达建造上限 (building_max_reached)
    static let maxBuildingsReached: LocalizedStringResource = "building_max_reached"

    /// 开始建造 (building_start_construction)
    static let startBuilding: LocalizedStringResource = "building_start_construction"

    // Building Format Strings
    /// 等级格式 "Tier %lld" (building_tier_format %lld)
    static let buildingTierFormat: LocalizedStringResource = "building_tier_format %lld"

    /// 上限格式 "Max %lld" (building_max_limit_format %lld)
    static let buildingMaxLimitFormat: LocalizedStringResource = "building_max_limit_format %lld"

    /// 建筑等级格式 "Lv.%lld" (building_level_format %lld)
    static let buildingLevelFormat: LocalizedStringResource = "building_level_format %lld"

    /// 建造开始格式 (building_construction_started_format)
    static let buildingConstructionStartedFormat: LocalizedStringResource = "building_construction_started_format"

    /// 已建数量格式 "Built %lld/%lld"
    static let builtFormat: LocalizedStringResource = "Built %lld/%lld"

    // MARK: - Auth (26 keys)

    /// 应用标题 (auth_app_title)
    static let authAppTitle: LocalizedStringResource = "auth_app_title"

    /// 应用口号 (auth_app_slogan)
    static let authAppSlogan: LocalizedStringResource = "auth_app_slogan"

    /// 返回 (auth_back)
    static let authBack: LocalizedStringResource = "auth_back"

    /// 验证码占位符 (auth_code_placeholder)
    static let authCodePlaceholder: LocalizedStringResource = "auth_code_placeholder"

    /// 验证码已发送到 (auth_code_sent_to)
    static let authCodeSentTo: LocalizedStringResource = "auth_code_sent_to"

    /// 完成注册 (auth_complete_registration)
    static let authCompleteRegistration: LocalizedStringResource = "auth_complete_registration"

    /// 确认密码 (auth_confirm_password)
    static let authConfirmPassword: LocalizedStringResource = "auth_confirm_password"

    /// 邮箱占位符 (auth_email_placeholder)
    static let authEmailPlaceholder: LocalizedStringResource = "auth_email_placeholder"

    /// 输入验证码 (auth_enter_code)
    static let authEnterCode: LocalizedStringResource = "auth_enter_code"

    /// 输入邮箱获取验证码 (auth_enter_email_for_code)
    static let authEnterEmailForCode: LocalizedStringResource = "auth_enter_email_for_code"

    /// 忘记密码 (auth_forgot_password)
    static let authForgotPassword: LocalizedStringResource = "auth_forgot_password"

    /// 前往登录 (auth_go_to_login)
    static let authGoToLogin: LocalizedStringResource = "auth_go_to_login"

    /// 登录 (auth_login)
    static let authLogin: LocalizedStringResource = "auth_login"

    /// 需要登录 (auth_login_required)
    static let authLoginRequired: LocalizedStringResource = "auth_login_required"

    /// 或使用以下方式登录 (auth_or_sign_in_with)
    static let authOrSignInWith: LocalizedStringResource = "auth_or_sign_in_with"

    /// 密码不匹配 (auth_password_mismatch)
    static let authPasswordMismatch: LocalizedStringResource = "auth_password_mismatch"

    /// 密码占位符 (auth_password_placeholder)
    static let authPasswordPlaceholder: LocalizedStringResource = "auth_password_placeholder"

    /// 注册 (auth_register)
    static let authRegister: LocalizedStringResource = "auth_register"

    /// 重新发送验证码 (auth_resend_code)
    static let authResendCode: LocalizedStringResource = "auth_resend_code"

    /// 倒计时 (auth_resend_countdown)
    static let authResendCountdown: LocalizedStringResource = "auth_resend_countdown"

    /// 发送验证码 (auth_send_code)
    static let authSendCode: LocalizedStringResource = "auth_send_code"

    /// 设置密码 (auth_set_password)
    static let authSetPassword: LocalizedStringResource = "auth_set_password"

    /// 设置密码提示 (auth_set_password_hint)
    static let authSetPasswordHint: LocalizedStringResource = "auth_set_password_hint"

    /// 密码强度不足提示 (auth_password_too_weak)
    static let authPasswordTooWeak: LocalizedStringResource = "auth_password_too_weak"

    /// 密码强度合格提示 (auth_password_valid)
    static let authPasswordValid: LocalizedStringResource = "auth_password_valid"

    /// 使用Apple登录 (auth_sign_in_apple)
    static let authSignInApple: LocalizedStringResource = "auth_sign_in_apple"

    /// 使用Google登录 (auth_sign_in_google)
    static let authSignInGoogle: LocalizedStringResource = "auth_sign_in_google"

    /// 验证 (auth_verify)
    static let authVerify: LocalizedStringResource = "auth_verify"

    // MARK: - Backpack & Exploration (20 keys)

    /// 背包标题 (backpack_title)
    static let backpackTitle: LocalizedStringResource = "backpack_title"

    /// 搜索占位符 (backpack_search_placeholder)
    static let backpackSearchPlaceholder: LocalizedStringResource = "backpack_search_placeholder"

    /// 背包空状态标题 (backpack_empty_title)
    static let backpackEmptyTitle: LocalizedStringResource = "backpack_empty_title"

    /// 背包空状态副标题 (backpack_empty_subtitle)
    static let backpackEmptySubtitle: LocalizedStringResource = "backpack_empty_subtitle"

    /// 无搜索结果标题 (backpack_no_results_title)
    static let backpackNoResultsTitle: LocalizedStringResource = "backpack_no_results_title"

    /// 无搜索结果副标题 (backpack_no_results_subtitle)
    static let backpackNoResultsSubtitle: LocalizedStringResource = "backpack_no_results_subtitle"

    /// 筛选全部 (filter_all)
    static let filterAll: LocalizedStringResource = "filter_all"

    /// 探索统计 (exploration_stats)
    static let explorationStats: LocalizedStringResource = "exploration_stats"

    /// 收集物品 (exploration_collected_items)
    static let explorationCollectedItems: LocalizedStringResource = "exploration_collected_items"

    /// 获得经验 (exploration_experience_gained)
    static let explorationExperienceGained: LocalizedStringResource = "exploration_experience_gained"

    /// 结果页存储已满警告 (result_storage_full_warning)
    static let resultStorageFullWarning: LocalizedStringResource = "result_storage_full_warning"

    /// 距离 (exploration_distance)
    static let explorationDistance: LocalizedStringResource = "exploration_distance"

    /// 时长 (exploration_duration)
    static let explorationDuration: LocalizedStringResource = "exploration_duration"

    /// 验证点数 (exploration_points_verified)
    static let explorationPointsVerified: LocalizedStringResource = "exploration_points_verified"

    /// 距离数值 (exploration_distance_value)
    static let explorationDistanceValue: LocalizedStringResource = "exploration_distance_value"

    /// 行走距离格式 (exploration_walked_format)
    static let explorationWalkedFormat: LocalizedStringResource = "exploration_walked_format"

    /// 探索失败 (exploration_failed)
    static let explorationFailed: LocalizedStringResource = "exploration_failed"

    /// 验证点计数格式 (exploration_points_count)
    static let explorationPointsCount: LocalizedStringResource = "exploration_points_count"

    /// 距离排名标签 (exploration_distance_rank)
    static let explorationDistanceRank: LocalizedStringResource = "exploration_distance_rank"

    /// 拾荒成功标题 (scavenge_success_title)
    static let scavengeSuccessTitle: LocalizedStringResource = "scavenge_success_title"

    /// 获得物品 (scavenge_items_obtained)
    static let scavengeItemsObtained: LocalizedStringResource = "scavenge_items_obtained"

    /// AI生成 (scavenge_ai_generated)
    static let scavengeAiGenerated: LocalizedStringResource = "scavenge_ai_generated"

    /// POI发现标题 (poi_discovery_title)
    static let poiDiscoveryTitle: LocalizedStringResource = "poi_discovery_title"

    /// 拾荒可用 (poi_scavenge_available)
    static let poiScavengeAvailable: LocalizedStringResource = "poi_scavenge_available"

    /// 立即拾荒 (poi_scavenge_now)
    static let poiScavengeNow: LocalizedStringResource = "poi_scavenge_now"

    // MARK: - Profile (30 keys)

    /// 设置 (profile_settings)
    static let profileSettings: LocalizedStringResource = "profile_settings"

    /// 账号安全 (profile_account_security)
    static let profileAccountSecurity: LocalizedStringResource = "profile_account_security"

    /// 账号安全开发中 (profile_account_security_dev)
    static let profileAccountSecurityDev: LocalizedStringResource = "profile_account_security_dev"

    /// 通知 (profile_notifications)
    static let profileNotifications: LocalizedStringResource = "profile_notifications"

    /// 通知开发中 (profile_notifications_dev)
    static let profileNotificationsDev: LocalizedStringResource = "profile_notifications_dev"

    /// 关于 (profile_about)
    static let profileAbout: LocalizedStringResource = "profile_about"

    /// 关于开发中 (profile_about_dev)
    static let profileAboutDev: LocalizedStringResource = "profile_about_dev"

    /// 应用设置 (profile_app_settings)
    static let profileAppSettings: LocalizedStringResource = "profile_app_settings"

    /// 语言 (profile_language)
    static let profileLanguage: LocalizedStringResource = "profile_language"

    /// 登出 (profile_logout)
    static let profileLogout: LocalizedStringResource = "profile_logout"

    /// 登出确认标题 (profile_logout_confirm_title)
    static let profileLogoutConfirmTitle: LocalizedStringResource = "profile_logout_confirm_title"

    /// 登出确认消息 (profile_logout_confirm_message)
    static let profileLogoutConfirmMessage: LocalizedStringResource = "profile_logout_confirm_message"

    /// 登出操作 (profile_logout_action)
    static let profileLogoutAction: LocalizedStringResource = "profile_logout_action"

    /// 删除账号 (profile_delete_account)
    static let profileDeleteAccount: LocalizedStringResource = "profile_delete_account"

    /// 删除账号警告 (profile_delete_account_warning)
    static let profileDeleteAccountWarning: LocalizedStringResource = "profile_delete_account_warning"

    /// 删除失败 (profile_delete_failed)
    static let profileDeleteFailed: LocalizedStringResource = "profile_delete_failed"

    /// 默认用户名 (profile_default_username)
    static let profileDefaultUsername: LocalizedStringResource = "profile_default_username"

    /// 无邮箱 (profile_no_email)
    static let profileNoEmail: LocalizedStringResource = "profile_no_email"

    /// 语言设置 (profile_language_settings)
    static let profileLanguageSettings: LocalizedStringResource = "profile_language_settings"

    /// 语言更新提示 (profile_language_update_note)
    static let profileLanguageUpdateNote: LocalizedStringResource = "profile_language_update_note"

    /// 确认删除账号 (profile_confirm_delete_account)
    static let profileConfirmDeleteAccount: LocalizedStringResource = "profile_confirm_delete_account"

    /// 删除不可逆 (profile_delete_irreversible)
    static let profileDeleteIrreversible: LocalizedStringResource = "profile_delete_irreversible"

    /// 删除数据警告 (profile_delete_data_warning)
    static let profileDeleteDataWarning: LocalizedStringResource = "profile_delete_data_warning"

    /// 删除确认文本要求 (profile_delete_confirm_required_text)
    static let profileDeleteConfirmRequiredText: LocalizedStringResource = "profile_delete_confirm_required_text"

    /// 删除确认提示 (profile_delete_confirm_prompt)
    static let profileDeleteConfirmPrompt: LocalizedStringResource = "profile_delete_confirm_prompt"

    /// 删除确认占位符 (profile_delete_confirm_placeholder)
    static let profileDeleteConfirmPlaceholder: LocalizedStringResource = "profile_delete_confirm_placeholder"

    /// 删除项：个人资料 (profile_delete_item_profile)
    static let profileDeleteItemProfile: LocalizedStringResource = "profile_delete_item_profile"

    /// 删除项：进度 (profile_delete_item_progress)
    static let profileDeleteItemProgress: LocalizedStringResource = "profile_delete_item_progress"

    /// 删除项：认证 (profile_delete_item_auth)
    static let profileDeleteItemAuth: LocalizedStringResource = "profile_delete_item_auth"

    /// 确认删除 (profile_confirm_delete)
    static let profileConfirmDelete: LocalizedStringResource = "profile_confirm_delete"

    /// 删除错误 (profile_delete_error)
    static let profileDeleteError: LocalizedStringResource = "profile_delete_error"

    // MARK: - Profile Dashboard (7 keys)

    /// 幸存者档案标题 (profile_survivor_title)
    static let profileSurvivorTitle: LocalizedStringResource = "profile_survivor_title"

    /// 统计：领地 (profile_stat_territory)
    static let profileStatTerritory: LocalizedStringResource = "profile_stat_territory"

    /// 统计：资源点 (profile_stat_resource_points)
    static let profileStatResourcePoints: LocalizedStringResource = "profile_stat_resource_points"

    /// 统计：探索距离 (profile_stat_exploration_distance)
    static let profileStatExplorationDistance: LocalizedStringResource = "profile_stat_exploration_distance"

    /// 物资商城 (profile_material_store)
    static let profileMaterialStore: LocalizedStringResource = "profile_material_store"

    /// 技术支持 (profile_tech_support)
    static let profileTechSupport: LocalizedStringResource = "profile_tech_support"

    /// 隐私政策 (profile_privacy_policy)
    static let profilePrivacyPolicy: LocalizedStringResource = "profile_privacy_policy"

    // MARK: - Profile Command Center (19 keys)

    /// 生存天数 (profile_days_survival)
    static let profileDaysSurvival: LocalizedStringResource = "profile_days_survival"

    /// 领地统计 (profile_stat_territories)
    static let profileStatTerritories: LocalizedStringResource = "profile_stat_territories"

    /// 建筑统计 (profile_stat_buildings_count)
    static let profileStatBuildingsCount: LocalizedStringResource = "profile_stat_buildings_count"

    /// POI统计 (profile_stat_poi)
    static let profileStatPOI: LocalizedStringResource = "profile_stat_poi"

    /// 编辑档案 (profile_edit_profile)
    static let profileEditProfile: LocalizedStringResource = "profile_edit_profile"

    /// 查看订阅 (profile_view_subscription)
    static let profileViewSubscription: LocalizedStringResource = "profile_view_subscription"

    /// 购买资源包 (profile_buy_resource_pack)
    static let profileBuyResourcePack: LocalizedStringResource = "profile_buy_resource_pack"

    /// 购买资源 — 仪表盘按钮短文案 (profile_buy_resource)
    static let profileBuyResource: LocalizedStringResource = "profile_buy_resource"

    /// 统计 (profile_statistics)
    static let profileStatistics: LocalizedStringResource = "profile_statistics"

    /// 排行榜 (profile_leaderboard)
    static let profileLeaderboard: LocalizedStringResource = "profile_leaderboard"

    /// 成就 (profile_achievements)
    static let profileAchievements: LocalizedStringResource = "profile_achievements"

    /// 状态 (profile_vitals)
    static let profileVitals: LocalizedStringResource = "profile_vitals"

    /// 数据驱动进度 (profile_data_driven)
    static let profileDataDriven: LocalizedStringResource = "profile_data_driven"

    /// 今天 (profile_today)
    static let profileToday: LocalizedStringResource = "profile_today"

    /// 本周 (profile_this_week)
    static let profileThisWeek: LocalizedStringResource = "profile_this_week"

    /// 本月 (profile_this_month)
    static let profileThisMonth: LocalizedStringResource = "profile_this_month"

    /// 全部 (profile_all_time)
    static let profileAllTime: LocalizedStringResource = "profile_all_time"

    /// 距离 (profile_stat_distance)
    static let profileStatDistance: LocalizedStringResource = "profile_stat_distance"

    /// 面积 (profile_stat_area)
    static let profileStatArea: LocalizedStringResource = "profile_stat_area"

    /// 资源 (profile_stat_resources)
    static let profileStatResources: LocalizedStringResource = "profile_stat_resources"

    /// 敬请期待 (profile_coming_soon)
    static let profileComingSoon: LocalizedStringResource = "profile_coming_soon"

    // MARK: - Map (3 keys)

    /// 领地已注册 (map_territory_registered)
    static let mapTerritoryRegistered: LocalizedStringResource = "map_territory_registered"

    /// 定位 (map_locate)
    static let mapLocate: LocalizedStringResource = "map_locate"

    /// 记录所有GPS更新 (map_record_all_gps_updates)
    static let mapRecordAllGpsUpdates: LocalizedStringResource = "map_record_all_gps_updates"

    // MARK: - Common (9 keys)

    /// 返回 (common_back)
    static let commonBack: LocalizedStringResource = "common_back"

    /// 取消 (common_cancel)
    static let commonCancel: LocalizedStringResource = "common_cancel"

    /// 确认 (common_confirm)
    static let commonConfirm: LocalizedStringResource = "common_confirm"

    /// 完成 (common_done)
    static let commonDone: LocalizedStringResource = "common_done"

    /// 稍后 (common_later)
    static let commonLater: LocalizedStringResource = "common_later"

    /// 加载中 (common_loading)
    static let commonLoading: LocalizedStringResource = "common_loading"

    /// 已锁定 (common_locked)
    static let commonLocked: LocalizedStringResource = "common_locked"

    /// 确定 (common_ok)
    static let commonOk: LocalizedStringResource = "common_ok"

    /// 重试 (common_retry)
    static let commonRetry: LocalizedStringResource = "common_retry"

    /// 通用错误 (common_error)
    static let commonError: LocalizedStringResource = "common_error"

    /// 删除 (common_delete)
    static let commonDelete: LocalizedStringResource = "common_delete"

    // MARK: - Tabs (4 keys)

    /// 地图 (tab_map)
    static let tabMap: LocalizedStringResource = "tab_map"

    /// 领地 (tab_territory)
    static let tabTerritory: LocalizedStringResource = "tab_territory"

    /// 资源 (tab_resources)
    static let tabResources: LocalizedStringResource = "tab_resources"

    /// 个人 (tab_profile)
    static let tabProfile: LocalizedStringResource = "tab_profile"

    /// 个人仪表盘 (tab_personal) — Personal dashboard tab label
    static let tabPersonal: LocalizedStringResource = "tab_personal"

    /// 商店 (tab_store)
    static let tabStore: LocalizedStringResource = "tab_store"

    // MARK: - Resources & Segments

    /// 背包资源 (inventory_resources)
    static let inventoryResources: LocalizedStringResource = "inventory_resources"

    /// 交易分段 (segment_trade)
    static let segmentTrade: LocalizedStringResource = "segment_trade"

    /// 功能开发中 (feature_in_development)
    static let featureInDevelopment: LocalizedStringResource = "feature_in_development"

    // MARK: - Building Categories

    /// 生存 (category_survival)
    static let categorySurvival: LocalizedStringResource = "category_survival"

    /// 仓储 (category_storage)
    static let categoryStorage: LocalizedStringResource = "category_storage"

    /// 生产 (category_production)
    static let categoryProduction: LocalizedStringResource = "category_production"

    /// 能源 (category_energy)
    static let categoryEnergy: LocalizedStringResource = "category_energy"

    // MARK: - Item Categories

    /// 水源 (category_water)
    static let categoryWater: LocalizedStringResource = "category_water"

    /// 食物 (category_food)
    static let categoryFood: LocalizedStringResource = "category_food"

    /// 医疗 (category_medical)
    static let categoryMedical: LocalizedStringResource = "category_medical"

    /// 材料 (category_material)
    static let categoryMaterial: LocalizedStringResource = "category_material"

    /// 工具 (category_tool)
    static let categoryTool: LocalizedStringResource = "category_tool"

    /// 武器 (category_weapon)
    static let categoryWeapon: LocalizedStringResource = "category_weapon"

    /// 其他 (category_other)
    static let categoryOther: LocalizedStringResource = "category_other"

    // MARK: - Item Quality

    /// 崭新 (quality_pristine)
    static let qualityPristine: LocalizedStringResource = "quality_pristine"

    /// 良好 (quality_good)
    static let qualityGood: LocalizedStringResource = "quality_good"

    /// 磨损 (quality_worn)
    static let qualityWorn: LocalizedStringResource = "quality_worn"

    /// 破损 (quality_damaged)
    static let qualityDamaged: LocalizedStringResource = "quality_damaged"

    /// 损毁 (quality_ruined)
    static let qualityRuined: LocalizedStringResource = "quality_ruined"

    // MARK: - Item Rarity

    /// 普通 (rarity_common)
    static let rarityCommon: LocalizedStringResource = "rarity_common"

    /// 优秀 (rarity_uncommon)
    static let rarityUncommon: LocalizedStringResource = "rarity_uncommon"

    /// 稀有 (rarity_rare)
    static let rarityRare: LocalizedStringResource = "rarity_rare"

    /// 史诗 (rarity_epic)
    static let rarityEpic: LocalizedStringResource = "rarity_epic"

    /// 传奇 (rarity_legendary)
    static let rarityLegendary: LocalizedStringResource = "rarity_legendary"

    // MARK: - Trade System (38 keys)

    /// 交易市场标题 (trade_market_title)
    static let tradeMarketTitle: LocalizedStringResource = "trade_market_title"

    /// 我的挂单 (trade_my_offers)
    static let tradeMyOffers: LocalizedStringResource = "trade_my_offers"

    /// 交易历史 (trade_history)
    static let tradeHistory: LocalizedStringResource = "trade_history"

    /// 创建挂单 (trade_create_offer)
    static let tradeCreateOffer: LocalizedStringResource = "trade_create_offer"

    /// 接受交易 (trade_accept)
    static let tradeAccept: LocalizedStringResource = "trade_accept"

    /// 取消挂单 (trade_cancel)
    static let tradeCancel: LocalizedStringResource = "trade_cancel"

    /// 评价交易 (trade_rate)
    static let tradeRate: LocalizedStringResource = "trade_rate"

    /// 提供物品 (trade_offering)
    static let tradeOffering: LocalizedStringResource = "trade_offering"

    /// 需要物品 (trade_requesting)
    static let tradeRequesting: LocalizedStringResource = "trade_requesting"

    /// 留言 (trade_message)
    static let tradeMessage: LocalizedStringResource = "trade_message"

    /// 有效期 (trade_validity)
    static let tradeValidity: LocalizedStringResource = "trade_validity"

    /// 过期时间 (trade_expires_at)
    static let tradeExpiresAt: LocalizedStringResource = "trade_expires_at"

    /// 发布者 (trade_owner)
    static let tradeOwner: LocalizedStringResource = "trade_owner"

    /// 接受者 (trade_accepter)
    static let tradeAccepter: LocalizedStringResource = "trade_accepter"

    /// 评分 (trade_rating)
    static let tradeRating: LocalizedStringResource = "trade_rating"

    /// 评语 (trade_comment)
    static let tradeComment: LocalizedStringResource = "trade_comment"

    /// 空挂单提示 (trade_empty_offers)
    static let tradeEmptyOffers: LocalizedStringResource = "trade_empty_offers"

    /// 空历史提示 (trade_empty_history)
    static let tradeEmptyHistory: LocalizedStringResource = "trade_empty_history"

    /// 确认接受 (trade_confirm_accept)
    static let tradeConfirmAccept: LocalizedStringResource = "trade_confirm_accept"

    /// 确认取消 (trade_confirm_cancel)
    static let tradeConfirmCancel: LocalizedStringResource = "trade_confirm_cancel"

    /// 交易成功 (trade_success)
    static let tradeSuccess: LocalizedStringResource = "trade_success"

    /// 已发布 (trade_published)
    static let tradePublished: LocalizedStringResource = "trade_published"

    /// 已过期标签 (trade_expired_label)
    static let tradeExpiredLabel: LocalizedStringResource = "trade_expired_label"

    // 交易状态
    /// 等待中 (trade_status_active)
    static let tradeStatusActive: LocalizedStringResource = "trade_status_active"

    /// 已完成 (trade_status_completed)
    static let tradeStatusCompleted: LocalizedStringResource = "trade_status_completed"

    /// 已取消 (trade_status_cancelled)
    static let tradeStatusCancelled: LocalizedStringResource = "trade_status_cancelled"

    /// 已过期 (trade_status_expired)
    static let tradeStatusExpired: LocalizedStringResource = "trade_status_expired"

    // 交易错误信息
    /// 物品不足错误 (trade_error_insufficient_items)
    /// 用法: String(format: String(localized: LocalizedString.tradeErrorInsufficientItems), itemId, needed, available)
    static let tradeErrorInsufficientItems: LocalizedStringResource = "trade_error_insufficient_items"

    /// 挂单不存在 (trade_error_offer_not_found)
    static let tradeErrorOfferNotFound: LocalizedStringResource = "trade_error_offer_not_found"

    /// 挂单未激活 (trade_error_offer_not_active)
    static let tradeErrorOfferNotActive: LocalizedStringResource = "trade_error_offer_not_active"

    /// 挂单已过期 (trade_error_offer_expired)
    static let tradeErrorOfferExpired: LocalizedStringResource = "trade_error_offer_expired"

    /// 不能接受自己的挂单 (trade_error_cannot_accept_own_offer)
    static let tradeErrorCannotAcceptOwnOffer: LocalizedStringResource = "trade_error_cannot_accept_own_offer"

    /// 不是挂单所有者 (trade_error_not_offer_owner)
    static let tradeErrorNotOfferOwner: LocalizedStringResource = "trade_error_not_offer_owner"

    /// 已经评价过 (trade_error_already_rated)
    static let tradeErrorAlreadyRated: LocalizedStringResource = "trade_error_already_rated"

    /// 参数无效 (trade_error_invalid_parameters)
    static let tradeErrorInvalidParameters: LocalizedStringResource = "trade_error_invalid_parameters"

    // MARK: - Trade System Extended (Additional 58 keys for UI)

    // 主标题
    static let tradeSystemTitle: LocalizedStringResource = "trade_system_title"

    // 空状态
    static let tradeNoOffersTitle: LocalizedStringResource = "trade_no_offers_title"
    static let tradeNoOffersSubtitle: LocalizedStringResource = "trade_no_offers_subtitle"
    static let tradeMarketEmptyTitle: LocalizedStringResource = "trade_market_empty_title"
    static let tradeMarketEmptySubtitle: LocalizedStringResource = "trade_market_empty_subtitle"
    static let tradeHistoryEmptyTitle: LocalizedStringResource = "trade_history_empty_title"
    static let tradeHistoryEmptySubtitle: LocalizedStringResource = "trade_history_empty_subtitle"

    // 操作按钮
    static let tradeCancelOffer: LocalizedStringResource = "trade_cancel_offer"
    static let tradePublishOffer: LocalizedStringResource = "trade_publish_offer"
    static let tradePublishing: LocalizedStringResource = "trade_publishing"
    static let tradeAddItem: LocalizedStringResource = "trade_add_item"
    static let tradeViewDetails: LocalizedStringResource = "trade_view_details"
    static let tradeAccepting: LocalizedStringResource = "trade_accepting"
    static let tradeRateNow: LocalizedStringResource = "trade_rate_now"
    static let tradeSubmitRating: LocalizedStringResource = "trade_submit_rating"
    static let tradeSubmitting: LocalizedStringResource = "trade_submitting"
    static let tradeConfirmAdd: LocalizedStringResource = "trade_confirm_add"
    static let tradeSelectAll: LocalizedStringResource = "trade_select_all"
    static let tradeCancelOfferTitle: LocalizedStringResource = "trade_cancel_offer_title"
    static let tradeOfferDetails: LocalizedStringResource = "trade_offer_details"
    static let tradeSelectItem: LocalizedStringResource = "trade_select_item"

    // 表单字段
    static let tradeOfferingItems: LocalizedStringResource = "trade_offering_items"
    static let tradeRequestingItems: LocalizedStringResource = "trade_requesting_items"
    static let tradeValidityPeriod: LocalizedStringResource = "trade_validity_period"
    static let tradeMessageOptional: LocalizedStringResource = "trade_message_optional"
    static let tradeMessagePlaceholder: LocalizedStringResource = "trade_message_placeholder"
    static let tradeCommentOptional: LocalizedStringResource = "trade_comment_optional"
    static let tradeCommentPlaceholder: LocalizedStringResource = "trade_comment_placeholder"

    // 卡片标签
    static let tradeIProvide: LocalizedStringResource = "trade_i_provide"
    static let tradeIWant: LocalizedStringResource = "trade_i_want"
    static let tradeTheyProvide: LocalizedStringResource = "trade_they_provide"
    static let tradeTheyWant: LocalizedStringResource = "trade_they_want"
    static let tradeYouGave: LocalizedStringResource = "trade_you_gave"
    static let tradeYouReceived: LocalizedStringResource = "trade_you_received"
    static let tradeYourRating: LocalizedStringResource = "trade_your_rating"
    static let tradePartnerRating: LocalizedStringResource = "trade_partner_rating"
    static let tradeNotRatedYet: LocalizedStringResource = "trade_not_rated_yet"
    static let tradePublishedAt: LocalizedStringResource = "trade_published_at"
    static let tradeYourInventory: LocalizedStringResource = "trade_your_inventory"

    // 状态和时间
    static let tradeExpired: LocalizedStringResource = "trade_expired"
    static let tradeRemainingHoursFormat: LocalizedStringResource = "trade_remaining_hours_format"
    static let tradeRemainingMinutesFormat: LocalizedStringResource = "trade_remaining_minutes_format"

    // 对话框和提示
    static let tradeCancelOfferMessage: LocalizedStringResource = "trade_cancel_offer_message"
    static let tradeConfirmTitle: LocalizedStringResource = "trade_confirm_title"
    static let tradeConfirmMessage: LocalizedStringResource = "trade_confirm_message"
    static let tradeYouWillPay: LocalizedStringResource = "trade_you_will_pay"
    static let tradeYouWillReceive: LocalizedStringResource = "trade_you_will_receive"
    static let tradeSuccessTitle: LocalizedStringResource = "trade_success_title"
    static let tradeSuccessMessage: LocalizedStringResource = "trade_success_message"
    static let tradeRateTitle: LocalizedStringResource = "trade_rate_title"
    static let tradeRateThisTrade: LocalizedStringResource = "trade_rate_this_trade"

    // 物品选择器
    static let tradeSearchItems: LocalizedStringResource = "trade_search_items"
    static let tradeNoItemsAvailable: LocalizedStringResource = "trade_no_items_available"
    static let tradeSelectQuantity: LocalizedStringResource = "trade_select_quantity"

    // 格式化字符串
    static let tradeInStockFormat: LocalizedStringResource = "trade_in_stock_format"
    static let tradeValidityHoursFormat: LocalizedStringResource = "trade_validity_hours_format"
    static let tradeValidityDaysFormat: LocalizedStringResource = "trade_validity_days_format"
    static let tradeAcceptedByFormat: LocalizedStringResource = "trade_accepted_by_format"

    // 其他
    static let tradeUnknownUser: LocalizedStringResource = "trade_unknown_user"
    static let tradeWithUserFormat: LocalizedStringResource = "trade_with_user_format"
    static let tradeDebugTools: LocalizedStringResource = "trade_debug_tools"
    static let tradeTestComplete: LocalizedStringResource = "trade_test_complete"
    static let tradeDebugFillInventory: LocalizedStringResource = "trade_debug_fill_inventory"
    static let tradeDebugTestDatabase: LocalizedStringResource = "trade_debug_test_database"
    static let tradeDebugCurrentConfig: LocalizedStringResource = "trade_debug_current_config"
    static let tradeDebugInventoryCount: LocalizedStringResource = "trade_debug_inventory_count"

    // MARK: - Communication (24 keys)

    /// Day 33 实现 (day_33_implementation)
    static let day33Implementation: LocalizedStringResource = "day_33_implementation"

    /// Day 34 实现 (day_34_implementation)
    static let day34Implementation: LocalizedStringResource = "day_34_implementation"

    /// Day 36 实现 (day_36_implementation)
    static let day36Implementation: LocalizedStringResource = "day_36_implementation"

    /// 仅接收 (receive_only)
    static let receiveOnly: LocalizedStringResource = "receive_only"

    /// 切换 (switch)
    static let switchDevice: LocalizedStringResource = "switch"

    /// 创建频道 (create_channel)
    static let createChannel: LocalizedStringResource = "create_channel"

    /// 可发送 (can_send)
    static let canSend: LocalizedStringResource = "can_send"

    /// 呼叫中心 (call_center)
    static let callCenter: LocalizedStringResource = "call_center"

    /// 官方频道 (official_channel)
    static let officialChannel: LocalizedStringResource = "official_channel"

    /// 当前 (current)
    static let current: LocalizedStringResource = "current"

    /// 所有设备 (all_devices)
    static let allDevices: LocalizedStringResource = "all_devices"

    /// 消息中心 (message_center)
    static let messageCenter: LocalizedStringResource = "message_center"

    /// 确定 (confirm) - 注意：已有 commonConfirm，但为了兼容性保留
    static let confirm: LocalizedStringResource = "confirm"

    /// 简体中文 (simplified_chinese)
    static let simplifiedChinese: LocalizedStringResource = "simplified_chinese"

    /// 聊天界面 (chat_interface)
    static let chatInterface: LocalizedStringResource = "chat_interface"

    /// 覆盖范围: %@ (coverage_format)
    static let coverageFormat: LocalizedStringResource = "coverage_format"

    /// 设备未解锁 (device_not_unlocked)
    static let deviceNotUnlocked: LocalizedStringResource = "device_not_unlocked"

    /// Satellite requires Archon tier (device_requires_archon_tier)
    static let deviceRequiresArchonTier: LocalizedStringResource = "device_requires_archon_tier"

    /// 设备管理 (device_management)
    static let deviceManagement: LocalizedStringResource = "device_management"

    /// 选择通讯设备，不同设备有不同覆盖范围 (select_communication_device)
    static let selectCommunicationDevice: LocalizedStringResource = "select_communication_device"

    /// 通讯 (communication) - Tab 标签，显示为 "Comms"
    static let communication: LocalizedStringResource = "communication"

    /// 通讯中心 (communication_center)
    static let communicationCenter: LocalizedStringResource = "communication_center"

    // MARK: - Communication Navigation (4 keys)

    /// 消息导航标签 (nav_messages)
    static let navMessages: LocalizedStringResource = "nav_messages"

    /// 频道导航标签 (nav_channels)
    static let navChannels: LocalizedStringResource = "nav_channels"

    /// 呼叫导航标签 (nav_calls)
    static let navCalls: LocalizedStringResource = "nav_calls"

    /// 设备导航标签 (nav_devices)
    static let navDevices: LocalizedStringResource = "nav_devices"

    // MARK: - Channel Management (5 keys)

    /// 重命名频道 (action_rename_channel)
    static let actionRenameChannel: LocalizedStringResource = "action_rename_channel"

    /// 删除频道 (action_delete_channel)
    static let actionDeleteChannel: LocalizedStringResource = "action_delete_channel"

    /// 请输入新名称 (rename_alert_title)
    static let renameAlertTitle: LocalizedStringResource = "rename_alert_title"

    /// 保存 (common_save)
    static let commonSave: LocalizedStringResource = "common_save"

    /// 确认删除频道 (delete_channel_confirm)
    static let deleteChannelConfirm: LocalizedStringResource = "delete_channel_confirm"

    // MARK: - Communication Devices (4 keys)

    /// 对讲机 (device_walkie_talkie)
    static let deviceWalkieTalkie: LocalizedStringResource = "device_walkie_talkie"

    /// 收音机 (device_radio)
    static let deviceRadio: LocalizedStringResource = "device_radio"

    /// 营地电台 (device_base_station)
    static let deviceBaseStation: LocalizedStringResource = "device_base_station"

    /// 卫星通讯 (device_satellite)
    static let deviceSatellite: LocalizedStringResource = "device_satellite"

    // MARK: - Communication Device Descriptions (4 keys)

    /// 只能接收信号，无法发送消息 (desc_receive_only)
    static let descReceiveOnly: LocalizedStringResource = "desc_receive_only"

    /// 可在 %lld 公里范围内通讯 (desc_comm_range_format)
    static let descCommRangeFormat: LocalizedStringResource = "desc_comm_range_format"

    /// 可在 %lld 公里范围内广播 (desc_broadcast_range_format)
    static let descBroadcastRangeFormat: LocalizedStringResource = "desc_broadcast_range_format"

    /// 可在 %lld+ 公里范围内联络 (desc_contact_range_format)
    static let descContactRangeFormat: LocalizedStringResource = "desc_contact_range_format"

    // MARK: - Communication Range (2 keys)

    /// 无限制（仅接收）(range_unlimited_receive_only)
    static let rangeUnlimitedReceiveOnly: LocalizedStringResource = "range_unlimited_receive_only"

    /// 覆盖范围：%lld 公里 (range_format)
    static let rangeFormat: LocalizedStringResource = "range_format"

    // MARK: - Communication Unlock Requirements (3 keys)

    /// 默认拥有 (unlock_default_owned)
    static let unlockDefaultOwned: LocalizedStringResource = "unlock_default_owned"

    /// 需建造「营地电台」建筑 (unlock_require_base_station)
    static let unlockRequireBaseStation: LocalizedStringResource = "unlock_require_base_station"

    /// 需建造「通讯塔」建筑 (unlock_require_comm_tower)
    static let unlockRequireCommTower: LocalizedStringResource = "unlock_require_comm_tower"

    // MARK: - Device Upgrade System (12 keys)

    /// 解锁需求 (upgrade_requirements)
    static let upgradeRequirements: LocalizedStringResource = "upgrade_requirements"

    /// 所需资源 (upgrade_needed_resources)
    static let upgradeNeededResources: LocalizedStringResource = "upgrade_needed_resources"

    /// 所需领地 (upgrade_needed_territories)
    static let upgradeNeededTerritories: LocalizedStringResource = "upgrade_needed_territories"

    /// 前置设备 (upgrade_prerequisite)
    static let upgradePrerequisite: LocalizedStringResource = "upgrade_prerequisite"

    /// 需要先解锁前置设备 (upgrade_prerequisite_required)
    static let upgradePrerequisiteRequired: LocalizedStringResource = "upgrade_prerequisite_required"

    /// 使用资源解锁 (upgrade_with_resources)
    static let upgradeWithResources: LocalizedStringResource = "upgrade_with_resources"

    /// 资源不足 (upgrade_insufficient_resources)
    static let upgradeInsufficientResources: LocalizedStringResource = "upgrade_insufficient_resources"

    /// 领地不足：拥有 %lld / 需要 %lld (upgrade_territories_format)
    static let upgradeTerritoriesFormat: LocalizedStringResource = "upgrade_territories_format"

    /// 已解锁 (upgrade_unlocked)
    static let upgradeUnlocked: LocalizedStringResource = "upgrade_unlocked"

    /// 解锁成功 (upgrade_success)
    static let upgradeSuccess: LocalizedStringResource = "upgrade_success"

    /// 频道中心 (channel_center)
    static let channelCenter: LocalizedStringResource = "channel_center"

    /// 频道列表 (channel_list)
    static let channelList: LocalizedStringResource = "channel_list"

    /// 频道详情 (channel_details)
    static let channelDetails: LocalizedStringResource = "channel_details"

    // MARK: - Channel Types (5 keys)

    /// 官方频道类型 (channel_type_official)
    static let channelTypeOfficial: LocalizedStringResource = "channel_type_official"

    /// 公共频道类型 (channel_type_public)
    static let channelTypePublic: LocalizedStringResource = "channel_type_public"

    /// 对讲机频道类型 (channel_type_walkie)
    static let channelTypeWalkie: LocalizedStringResource = "channel_type_walkie"

    /// 营地频道类型 (channel_type_camp)
    static let channelTypeCamp: LocalizedStringResource = "channel_type_camp"

    /// 卫星频道类型 (channel_type_satellite)
    static let channelTypeSatellite: LocalizedStringResource = "channel_type_satellite"

    // MARK: - Channel Type Descriptions (5 keys)

    /// 官方频道描述 (channel_desc_official)
    static let channelDescOfficial: LocalizedStringResource = "channel_desc_official"

    /// 公共频道描述 (channel_desc_public)
    static let channelDescPublic: LocalizedStringResource = "channel_desc_public"

    /// 对讲机频道描述 (channel_desc_walkie)
    static let channelDescWalkie: LocalizedStringResource = "channel_desc_walkie"

    /// 营地频道描述 (channel_desc_camp)
    static let channelDescCamp: LocalizedStringResource = "channel_desc_camp"

    /// 卫星频道描述 (channel_desc_satellite)
    static let channelDescSatellite: LocalizedStringResource = "channel_desc_satellite"

    // MARK: - Channel Operations (12 keys)

    /// 我的频道 (my_channels)
    static let myChannels: LocalizedStringResource = "my_channels"

    /// 发现频道 (discover_channels)
    static let discoverChannels: LocalizedStringResource = "discover_channels"

    /// 订阅 (subscribe)
    static let subscribe: LocalizedStringResource = "subscribe"

    /// 取消订阅 (unsubscribe)
    static let unsubscribe: LocalizedStringResource = "unsubscribe"

    /// 删除频道 (delete_channel)
    static let deleteChannel: LocalizedStringResource = "delete_channel"

    /// 确认删除 (confirm_delete)
    static let confirmDelete: LocalizedStringResource = "confirm_delete"

    /// 频道名称 (channel_name)
    static let channelName: LocalizedStringResource = "channel_name"

    /// 频道描述 (channel_description)
    static let channelDescription: LocalizedStringResource = "channel_description"

    /// 选择频道类型 (select_channel_type)
    static let selectChannelType: LocalizedStringResource = "select_channel_type"

    /// 成员数量 (member_count)
    static let memberCount: LocalizedStringResource = "member_count"

    /// 已订阅 (subscribed)
    static let subscribed: LocalizedStringResource = "subscribed"

    /// 频道码 (channel_code)
    static let channelCode: LocalizedStringResource = "channel_code"

    // MARK: - Channel UI (15 keys)

    /// 创建频道中 (creating_channel)
    static let creatingChannel: LocalizedStringResource = "creating_channel"

    /// 搜索频道 (search_channels)
    static let searchChannels: LocalizedStringResource = "search_channels"

    /// 频道信息 (channel_info)
    static let channelInfo: LocalizedStringResource = "channel_info"

    /// 频道类型 (channel_type)
    static let channelType: LocalizedStringResource = "channel_type"

    /// 创建时间 (created_at)
    static let createdAt: LocalizedStringResource = "created_at"

    /// 暂无频道 (no_channels)
    static let noChannels: LocalizedStringResource = "no_channels"

    /// 暂无订阅频道 (no_subscribed_channels)
    static let noSubscribedChannels: LocalizedStringResource = "no_subscribed_channels"

    /// 开始创建你的第一个频道 (create_first_channel_hint)
    static let createFirstChannelHint: LocalizedStringResource = "create_first_channel_hint"

    /// 订阅频道以获取更新 (subscribe_channels_hint)
    static let subscribeChannelsHint: LocalizedStringResource = "subscribe_channels_hint"

    /// 删除频道确认消息 (delete_channel_confirm_message)
    static let deleteChannelConfirmMessage: LocalizedStringResource = "delete_channel_confirm_message"

    /// 名称长度提示 (channel_name_length_hint)
    static let channelNameLengthHint: LocalizedStringResource = "channel_name_length_hint"

    /// 名称过短 (channel_name_too_short)
    static let channelNameTooShort: LocalizedStringResource = "channel_name_too_short"

    /// 名称过长 (channel_name_too_long)
    static let channelNameTooLong: LocalizedStringResource = "channel_name_too_long"

    /// 成员数量格式 (member_count_format)
    static let memberCountFormat: LocalizedStringResource = "member_count_format"

    /// 频道创建者 (channel_creator)
    static let channelCreator: LocalizedStringResource = "channel_creator"

    // MARK: - Message System (Day 34, 11 keys)

    /// Send button (message_send)
    static let messageSend: LocalizedStringResource = "message_send"

    /// Type a message placeholder (message_placeholder)
    static let messagePlaceholder: LocalizedStringResource = "message_placeholder"

    /// Messages title (messages_title)
    static let messagesTitle: LocalizedStringResource = "messages_title"

    /// Just now (message_just_now)
    static let messageJustNow: LocalizedStringResource = "message_just_now"

    /// X minutes ago format (message_minutes_ago_format)
    static let messageMinutesAgoFormat: LocalizedStringResource = "message_minutes_ago_format"

    /// X hours ago format (message_hours_ago_format)
    static let messageHoursAgoFormat: LocalizedStringResource = "message_hours_ago_format"

    /// No messages yet (message_empty)
    static let messageEmpty: LocalizedStringResource = "message_empty"

    /// Start the conversation (message_empty_hint)
    static let messageEmptyHint: LocalizedStringResource = "message_empty_hint"

    /// Radio mode hint (message_radio_mode_hint)
    static let messageRadioModeHint: LocalizedStringResource = "message_radio_mode_hint"

    /// Sending (message_sending)
    static let messageSending: LocalizedStringResource = "message_sending"

    /// Enter chat (enter_chat)
    static let enterChat: LocalizedStringResource = "enter_chat"

    // MARK: - Day 36: Message Categories (4 keys)

    /// Survival Guide category (category_survival_guide)
    static let categorySurvivalGuide: LocalizedStringResource = "category_survival_guide"

    /// Game News category (category_game_news)
    static let categoryGameNews: LocalizedStringResource = "category_game_news"

    /// Mission Release category (category_mission_release)
    static let categoryMissionRelease: LocalizedStringResource = "category_mission_release"

    /// Emergency Alert category (category_emergency_alert)
    static let categoryEmergencyAlert: LocalizedStringResource = "category_emergency_alert"

    /// All categories (category_all)
    static let categoryAll: LocalizedStringResource = "category_all"

    // MARK: - Day 36: Official Channel UI (5 keys)

    /// Official Announcement (official_announcement)
    static let officialAnnouncement: LocalizedStringResource = "official_announcement"

    /// Global Coverage (global_coverage)
    static let globalCoverage: LocalizedStringResource = "global_coverage"

    /// No Announcements (no_announcements)
    static let noAnnouncements: LocalizedStringResource = "no_announcements"

    /// No category messages format (no_category_messages_format)
    static let noCategoryMessagesFormat: LocalizedStringResource = "no_category_messages_format"

    // MARK: - Day 36: PTT Call (8 keys)

    /// PTT Call title (ptt_call_title)
    static let pttCallTitle: LocalizedStringResource = "ptt_call_title"

    /// Call Content (call_content)
    static let callContent: LocalizedStringResource = "call_content"

    /// Call content placeholder (call_content_placeholder)
    static let callContentPlaceholder: LocalizedStringResource = "call_content_placeholder"

    /// Press to Send (press_to_send)
    static let pressToSend: LocalizedStringResource = "press_to_send"

    /// Sending (sending)
    static let sending: LocalizedStringResource = "sending"

    /// Message Sent (message_sent)
    static let messageSent: LocalizedStringResource = "message_sent"

    /// Hold to call hint (hold_to_call_hint)
    static let holdToCallHint: LocalizedStringResource = "hold_to_call_hint"

    // MARK: - Day 36: Callsign Settings (12 keys)

    /// Callsign Settings (callsign_settings)
    static let callsignSettings: LocalizedStringResource = "callsign_settings"

    /// What is Callsign (what_is_callsign)
    static let whatIsCallsign: LocalizedStringResource = "what_is_callsign"

    /// Callsign explanation (callsign_explanation)
    static let callsignExplanation: LocalizedStringResource = "callsign_explanation"

    /// Recommended Format (recommended_format)
    static let recommendedFormat: LocalizedStringResource = "recommended_format"

    /// Your Callsign (your_callsign)
    static let yourCallsign: LocalizedStringResource = "your_callsign"

    /// Callsign placeholder (callsign_placeholder)
    static let callsignPlaceholder: LocalizedStringResource = "callsign_placeholder"

    /// Callsign format hint (callsign_format_hint)
    static let callsignFormatHint: LocalizedStringResource = "callsign_format_hint"

    /// Save Callsign (save_callsign)
    static let saveCallsign: LocalizedStringResource = "save_callsign"

    /// Callsign Saved (callsign_saved)
    static let callsignSaved: LocalizedStringResource = "callsign_saved"

    /// Callsign updated format (callsign_updated_format)
    static let callsignUpdatedFormat: LocalizedStringResource = "callsign_updated_format"

    /// Callsign invalid format error (callsign_invalid_format)
    static let callsignInvalidFormat: LocalizedStringResource = "callsign_invalid_format"

    /// Not Set (not_set)
    static let notSet: LocalizedStringResource = "not_set"

    // MARK: - Day 36: Message Center (4 keys)

    /// No Messages (no_messages)
    static let noMessages: LocalizedStringResource = "no_messages"

    /// Subscribe to see messages hint (subscribe_to_see_messages)
    static let subscribeToSeeMessages: LocalizedStringResource = "subscribe_to_see_messages"

    /// Refresh (refresh)
    static let refresh: LocalizedStringResource = "refresh"

    /// Official badge (official_badge)
    static let officialBadge: LocalizedStringResource = "official_badge"

    // MARK: - Distance Filtering (Day 35-A, 4 keys)

    /// Message out of range (distance_out_of_range)
    static let distanceOutOfRange: LocalizedStringResource = "distance_out_of_range"

    /// Distance in km format (distance_km_format)
    static let distanceKmFormat: LocalizedStringResource = "distance_km_format"

    /// Message filtered by distance (distance_message_filtered)
    static let distanceMessageFiltered: LocalizedStringResource = "distance_message_filtered"

    /// Sender too far format (distance_sender_too_far_format)
    static let distanceSenderTooFarFormat: LocalizedStringResource = "distance_sender_too_far_format"

    // MARK: - Display Format (2 keys)

    /// ID 显示格式 (id_display_format)
    static let idDisplayFormat: LocalizedStringResource = "id_display_format"

    /// 添加材料（调试）(debug_add_materials)
    static let debugAddMaterials: LocalizedStringResource = "debug_add_materials"

    // MARK: - Store & IAP (30 keys)

    /// Store tab title (store_title)
    static let storeTitle: LocalizedStringResource = "store_title"

    /// Subscriptions section header (store_subscriptions)
    static let storeSubscriptions: LocalizedStringResource = "store_subscriptions"

    /// Items section header (store_items)
    static let storeItems: LocalizedStringResource = "store_items"

    /// Premium currency section header (store_premium_currency)
    static let storePremiumCurrency: LocalizedStringResource = "store_premium_currency"

    /// Refresh Store button (store_refresh)
    static let storeRefresh: LocalizedStringResource = "store_refresh"

    /// Restore Purchases button (store_restore_purchases)
    static let storeRestorePurchases: LocalizedStringResource = "store_restore_purchases"

    /// Purchase successful message (store_purchase_successful)
    static let storePurchaseSuccessful: LocalizedStringResource = "store_purchase_successful"

    /// Purchase failed error (store_purchase_failed)
    static let storePurchaseFailed: LocalizedStringResource = "store_purchase_failed"

    /// Verification failed error (store_verification_failed)
    static let storeVerificationFailed: LocalizedStringResource = "store_verification_failed"

    /// Network error (store_network_error)
    static let storeNetworkError: LocalizedStringResource = "store_network_error"

    /// Current plan badge (store_current_plan)
    static let storeCurrentPlan: LocalizedStringResource = "store_current_plan"

    /// Upgrade button (store_upgrade)
    static let storeUpgrade: LocalizedStringResource = "store_upgrade"

    /// Subscribe button (store_subscribe)
    static let storeSubscribe: LocalizedStringResource = "store_subscribe"

    /// Already purchased badge (store_already_purchased)
    static let storeAlreadyPurchased: LocalizedStringResource = "store_already_purchased"

    /// Purchased badge (store_purchased)
    static let storePurchased: LocalizedStringResource = "store_purchased"

    /// Best value badge (store_best_value)
    static let storeBestValue: LocalizedStringResource = "store_best_value"

    /// Popular badge (store_popular)
    static let storePopular: LocalizedStringResource = "store_popular"

    /// Per month suffix (store_per_month)
    static let storePerMonth: LocalizedStringResource = "store_per_month"

    /// Per year suffix (store_per_year)
    static let storePerYear: LocalizedStringResource = "store_per_year"

    /// Monthly plan toggle label (monthly_plan)
    static let monthlyPlan: LocalizedStringResource = "monthly_plan"

    /// Yearly plan toggle label (yearly_plan)
    static let yearlyPlan: LocalizedStringResource = "yearly_plan"

    /// Loading products indicator (store_loading_products)
    static let storeLoadingProducts: LocalizedStringResource = "store_loading_products"

    /// No products available message (store_no_products)
    static let storeNoProducts: LocalizedStringResource = "store_no_products"

    /// Restore completed message (store_restore_completed)
    static let storeRestoreCompleted: LocalizedStringResource = "store_restore_completed"

    /// Subscription renewal date format (subscription_renews_on)
    static let subscriptionRenewsOn: LocalizedStringResource = "subscription_renews_on"

    /// Subscription expired label (subscription_expired)
    static let subscriptionExpired: LocalizedStringResource = "subscription_expired"

    /// Subscription expires in N days format (subscription_expires_in_days_format)
    static let subscriptionExpiresInDaysFormat: LocalizedStringResource = "subscription_expires_in_days_format"

    /// Manage subscription button (manage_subscription)
    static let manageSubscription: LocalizedStringResource = "manage_subscription"

    /// Auto-renewal disclosure text for App Store compliance (store_auto_renewal_disclosure)
    static let storeAutoRenewalDisclosure: LocalizedStringResource = "store_auto_renewal_disclosure"

    /// Terms of Service link text (store_terms_of_service)
    static let storeTermsOfService: LocalizedStringResource = "store_terms_of_service"

    // MARK: - Subscription Tier Names (4 keys)

    /// Free tier name (tier_free)
    static let tierFree: LocalizedStringResource = "tier_free"

    /// Scavenger tier name (tier_scavenger)
    static let tierScavenger: LocalizedStringResource = "tier_scavenger"

    /// Pioneer tier name (tier_pioneer)
    static let tierPioneer: LocalizedStringResource = "tier_pioneer"

    /// Archon tier name (tier_archon)
    static let tierArchon: LocalizedStringResource = "tier_archon"

    // MARK: - Subscription Benefits (8 keys — only real, implemented benefits)

    /// 5 Territories (store_benefit_territories_5)
    static let storeBenefitTerritories5: LocalizedStringResource = "store_benefit_territories_5"

    /// 10 Territories (store_benefit_territories_10)
    static let storeBenefitTerritories10: LocalizedStringResource = "store_benefit_territories_10"

    /// 25 Territories (store_benefit_territories_25)
    static let storeBenefitTerritories25: LocalizedStringResource = "store_benefit_territories_25"

    /// 5 Daily AI Scans (store_benefit_daily_scans_5)
    static let storeBenefitDailyScans5: LocalizedStringResource = "store_benefit_daily_scans_5"

    /// 10 Daily AI Scans (store_benefit_daily_scans_10)
    static let storeBenefitDailyScans10: LocalizedStringResource = "store_benefit_daily_scans_10"

    /// Storage 150 (store_benefit_storage_150)
    static let storeBenefitStorage150: LocalizedStringResource = "store_benefit_storage_150"

    /// Storage 300 (store_benefit_storage_300)
    static let storeBenefitStorage300: LocalizedStringResource = "store_benefit_storage_300"

    /// Storage 600 (store_benefit_storage_600)
    static let storeBenefitStorage600: LocalizedStringResource = "store_benefit_storage_600"

    // MARK: - Vault Tab (8 keys)

    /// Vault segment label (segment_vault)
    static let segmentVault: LocalizedStringResource = "segment_vault"

    /// Vault membership tier label (vault_membership_tier)
    static let vaultMembershipTier: LocalizedStringResource = "vault_membership_tier"

    /// Vault Aether Energy label (vault_aether_energy)
    static let vaultAetherEnergy: LocalizedStringResource = "vault_aether_energy"

    /// Buy More button (vault_buy_more)
    static let vaultBuyMore: LocalizedStringResource = "vault_buy_more"

    /// Unlimited badge text (vault_unlimited)
    static let vaultUnlimited: LocalizedStringResource = "vault_unlimited"

    /// Go to Store link (vault_go_to_store)
    static let vaultGoToStore: LocalizedStringResource = "vault_go_to_store"

    /// Storage label (vault_storage)
    static let vaultStorage: LocalizedStringResource = "vault_storage"

    /// Storage full warning (vault_storage_full)
    static let vaultStorageFull: LocalizedStringResource = "vault_storage_full"

    // MARK: - Store Sections (1 key)

    /// Energy Packs section header (store_energy_packs)
    static let storeEnergyPacks: LocalizedStringResource = "store_energy_packs"

    // MARK: - Resource Names (store exchange display)
    static let resourceWood: LocalizedStringResource = "resource_wood"
    static let resourceStone: LocalizedStringResource = "resource_stone"
    static let resourceMetal: LocalizedStringResource = "resource_metal"
    static let resourceFabric: LocalizedStringResource = "resource_fabric"

    /// Unlimited AI Scans benefit for Archon (store_benefit_unlimited_scans)
    static let storeBenefitUnlimitedScans: LocalizedStringResource = "store_benefit_unlimited_scans"

    // MARK: - Energy Depleted Alert (3 keys)

    /// Energy depleted alert title (energy_depleted_title)
    static let energyDepletedTitle: LocalizedStringResource = "energy_depleted_title"

    /// Energy depleted alert message (energy_depleted_message)
    static let energyDepletedMessage: LocalizedStringResource = "energy_depleted_message"

    /// Energy depleted go to store button (energy_depleted_go_to_store)
    static let energyDepletedGoToStore: LocalizedStringResource = "energy_depleted_go_to_store"

    // MARK: - Splash & Actions

    /// Skip action button (action_skip)
    static let actionSkip: LocalizedStringResource = "action_skip"

    // MARK: - Onboarding (14 keys)

    /// Onboarding slide 1 title: Protocol (onboarding_title_protocol)
    static let onboardingTitleProtocol: LocalizedStringResource = "onboarding_title_protocol"

    /// Onboarding slide 1 description (onboarding_desc_protocol)
    static let onboardingDescProtocol: LocalizedStringResource = "onboarding_desc_protocol"

    /// Onboarding slide 2 title: Claiming (onboarding_title_claiming)
    static let onboardingTitleClaiming: LocalizedStringResource = "onboarding_title_claiming"

    /// Onboarding slide 2 description (onboarding_desc_claiming)
    static let onboardingDescClaiming: LocalizedStringResource = "onboarding_desc_claiming"

    /// Onboarding slide 3 title: Scavenging (onboarding_title_scavenging)
    static let onboardingTitleScavenging: LocalizedStringResource = "onboarding_title_scavenging"

    /// Onboarding slide 3 description (onboarding_desc_scavenging)
    static let onboardingDescScavenging: LocalizedStringResource = "onboarding_desc_scavenging"

    /// Onboarding slide 4 title: Comms (onboarding_title_comms)
    static let onboardingTitleComms: LocalizedStringResource = "onboarding_title_comms"

    /// Onboarding slide 4 description (onboarding_desc_comms)
    static let onboardingDescComms: LocalizedStringResource = "onboarding_desc_comms"

    /// Onboarding slide 5 title: Economy (onboarding_title_economy)
    static let onboardingTitleEconomy: LocalizedStringResource = "onboarding_title_economy"

    /// Onboarding slide 5 description (onboarding_desc_economy)
    static let onboardingDescEconomy: LocalizedStringResource = "onboarding_desc_economy"

    /// Skip button (onboarding_skip)
    static let onboardingSkip: LocalizedStringResource = "onboarding_skip"

    /// Start Journey button (onboarding_start_journey)
    static let onboardingStartJourney: LocalizedStringResource = "onboarding_start_journey"

    /// Manual / Operations Manual settings row (onboarding_manual)
    static let onboardingManual: LocalizedStringResource = "onboarding_manual"

    /// Onboarding main headline (onboarding_headline)
    static let onboardingHeadline: LocalizedStringResource = "onboarding_headline"

    // MARK: - Product Detail Sheet (22 keys)

    /// Scavenger tier headline (detail_scavenger_headline)
    static let detailScavengerHeadline: LocalizedStringResource = "detail_scavenger_headline"
    /// Pioneer tier headline (detail_pioneer_headline)
    static let detailPioneerHeadline: LocalizedStringResource = "detail_pioneer_headline"
    /// Archon tier headline (detail_archon_headline)
    static let detailArchonHeadline: LocalizedStringResource = "detail_archon_headline"
    /// Energy pack headline (detail_energy_headline)
    static let detailEnergyHeadline: LocalizedStringResource = "detail_energy_headline"

    /// Scavenger tier description (detail_scavenger_desc)
    static let detailScavengerDesc: LocalizedStringResource = "detail_scavenger_desc"
    /// Pioneer tier description (detail_pioneer_desc)
    static let detailPioneerDesc: LocalizedStringResource = "detail_pioneer_desc"
    /// Archon tier description (detail_archon_desc)
    static let detailArchonDesc: LocalizedStringResource = "detail_archon_desc"
    /// Energy pack description (detail_energy_desc)
    static let detailEnergyDesc: LocalizedStringResource = "detail_energy_desc"

    /// Comparison "Now" column header (detail_now)
    static let detailNow: LocalizedStringResource = "detail_now"
    /// Comparison "After" column header (detail_after)
    static let detailAfter: LocalizedStringResource = "detail_after"
    /// Territories label (detail_label_territories)
    static let detailLabelTerritories: LocalizedStringResource = "detail_label_territories"
    /// Daily Energy label (detail_label_daily_energy)
    static let detailLabelDailyEnergy: LocalizedStringResource = "detail_label_daily_energy"
    /// Storage label (detail_label_storage)
    static let detailLabelStorage: LocalizedStringResource = "detail_label_storage"
    /// AI Scans label (detail_label_ai_scans)
    static let detailLabelAIScans: LocalizedStringResource = "detail_label_ai_scans"
    /// Energy balance label (detail_label_energy)
    static let detailLabelEnergy: LocalizedStringResource = "detail_label_energy"
    /// Unlimited value display (detail_unlimited)
    static let detailUnlimited: LocalizedStringResource = "detail_unlimited"
    /// Each scan costs 1 energy (detail_energy_cost_per_scan)
    static let detailEnergyCostPerScan: LocalizedStringResource = "detail_energy_cost_per_scan"
    /// Scan POIs to discover items (detail_energy_scan_pois)
    static let detailEnergyScanPois: LocalizedStringResource = "detail_energy_scan_pois"
    /// Get N AI scans (detail_energy_scans_count)
    static let detailEnergyScansCount: LocalizedStringResource = "detail_energy_scans_count"

    // MARK: - Leaderboard (15 keys)

    /// Leaderboard category: Territory Area (leaderboard_category_territory)
    static let leaderboardCategoryTerritory: LocalizedStringResource = "leaderboard_category_territory"

    /// Leaderboard category: POI (leaderboard_category_poi)
    static let leaderboardCategoryPOI: LocalizedStringResource = "leaderboard_category_poi"

    /// Leaderboard category: Building (leaderboard_category_building)
    static let leaderboardCategoryBuilding: LocalizedStringResource = "leaderboard_category_building"

    /// My Score (leaderboard_my_score)
    static let leaderboardMyScore: LocalizedStringResource = "leaderboard_my_score"

    /// My Rank (leaderboard_my_rank)
    static let leaderboardMyRank: LocalizedStringResource = "leaderboard_my_rank"

    /// No leaderboard data (leaderboard_no_data)
    static let leaderboardNoData: LocalizedStringResource = "leaderboard_no_data"

    // MARK: - Achievements (25 keys)

    /// Achievement Progress (achievement_progress)
    static let achievementProgress: LocalizedStringResource = "achievement_progress"

    /// Unlocked (achievement_unlocked)
    static let achievementUnlocked: LocalizedStringResource = "achievement_unlocked"

    /// Locked (achievement_locked)
    static let achievementLocked: LocalizedStringResource = "achievement_locked"

    /// All category (achievement_category_all)
    static let achievementCategoryAll: LocalizedStringResource = "achievement_category_all"

    /// Exploration category (achievement_category_exploration)
    static let achievementCategoryExploration: LocalizedStringResource = "achievement_category_exploration"

    /// Building category (achievement_category_building)
    static let achievementCategoryBuilding: LocalizedStringResource = "achievement_category_building"

    /// Survival category (achievement_category_survival)
    static let achievementCategorySurvival: LocalizedStringResource = "achievement_category_survival"

    /// Show Unlocked Only (achievement_show_unlocked)
    static let achievementShowUnlocked: LocalizedStringResource = "achievement_show_unlocked"

    /// No achievements yet (achievement_empty)
    static let achievementEmpty: LocalizedStringResource = "achievement_empty"

    // Achievement names + descriptions (10 pairs)
    static let achievementFirstClaimName: LocalizedStringResource = "achievement_first_claim_name"
    static let achievementFirstClaimDesc: LocalizedStringResource = "achievement_first_claim_desc"
    static let achievementLandBaronName: LocalizedStringResource = "achievement_land_baron_name"
    static let achievementLandBaronDesc: LocalizedStringResource = "achievement_land_baron_desc"
    static let achievementFirstStepsName: LocalizedStringResource = "achievement_first_steps_name"
    static let achievementFirstStepsDesc: LocalizedStringResource = "achievement_first_steps_desc"
    static let achievementMarathonName: LocalizedStringResource = "achievement_marathon_name"
    static let achievementMarathonDesc: LocalizedStringResource = "achievement_marathon_desc"
    static let achievementTerritoryLordName: LocalizedStringResource = "achievement_territory_lord_name"
    static let achievementTerritoryLordDesc: LocalizedStringResource = "achievement_territory_lord_desc"
    static let achievementConstructorName: LocalizedStringResource = "achievement_constructor_name"
    static let achievementConstructorDesc: LocalizedStringResource = "achievement_constructor_desc"
    static let achievementArchitectName: LocalizedStringResource = "achievement_architect_name"
    static let achievementArchitectDesc: LocalizedStringResource = "achievement_architect_desc"
    static let achievementScoutName: LocalizedStringResource = "achievement_scout_name"
    static let achievementScoutDesc: LocalizedStringResource = "achievement_scout_desc"
    static let achievementWeekSurvivorName: LocalizedStringResource = "achievement_week_survivor_name"
    static let achievementWeekSurvivorDesc: LocalizedStringResource = "achievement_week_survivor_desc"
    static let achievementVeteranName: LocalizedStringResource = "achievement_veteran_name"
    static let achievementVeteranDesc: LocalizedStringResource = "achievement_veteran_desc"

    // MARK: - Vitals (10 keys)

    /// Active Buffs (vitals_active_buffs)
    static let vitalsActiveBuffs: LocalizedStringResource = "vitals_active_buffs"

    /// No Active Buffs (vitals_no_active_buffs)
    static let vitalsNoActiveBuffs: LocalizedStringResource = "vitals_no_active_buffs"

    /// Buff hint (vitals_buff_hint)
    static let vitalsBuffHint: LocalizedStringResource = "vitals_buff_hint"

    /// Core Health (vitals_core_health)
    static let vitalsCoreHealth: LocalizedStringResource = "vitals_core_health"

    /// Basic Vitals (vitals_basic_vitals)
    static let vitalsBasicVitals: LocalizedStringResource = "vitals_basic_vitals"

    /// Status Good (vitals_status_good)
    static let vitalsStatusGood: LocalizedStringResource = "vitals_status_good"

    /// Fullness (vitals_fullness)
    static let vitalsFullness: LocalizedStringResource = "vitals_fullness"

    /// Hydration (vitals_hydration)
    static let vitalsHydration: LocalizedStringResource = "vitals_hydration"

    /// Tip (vitals_tip)
    static let vitalsTip: LocalizedStringResource = "vitals_tip"

    // MARK: - Detailed Stats (10 keys)

    /// Detailed Statistics title (detailed_stats_title)
    static let detailedStatsTitle: LocalizedStringResource = "detailed_stats_title"

    /// Exploration Stats section (detailed_stats_exploration)
    static let detailedStatsExploration: LocalizedStringResource = "detailed_stats_exploration"

    /// Activity Stats section (detailed_stats_activity)
    static let detailedStatsActivity: LocalizedStringResource = "detailed_stats_activity"

    /// Resource Stats section (detailed_stats_resources)
    static let detailedStatsResources: LocalizedStringResource = "detailed_stats_resources"

    /// Distance label (detailed_stats_distance)
    static let detailedStatsDistance: LocalizedStringResource = "detailed_stats_distance"

    /// Area label (detailed_stats_area)
    static let detailedStatsArea: LocalizedStringResource = "detailed_stats_area"

    /// Territories label (detailed_stats_territories)
    static let detailedStatsTerritories: LocalizedStringResource = "detailed_stats_territories"

    /// POIs Found label (detailed_stats_pois)
    static let detailedStatsPOIs: LocalizedStringResource = "detailed_stats_pois"

    /// Calories label (detailed_stats_calories)
    static let detailedStatsCalories: LocalizedStringResource = "detailed_stats_calories"

    /// Game Time label (detailed_stats_game_time)
    static let detailedStatsGameTime: LocalizedStringResource = "detailed_stats_game_time"

    /// Steps label (detailed_stats_steps)
    static let detailedStatsSteps: LocalizedStringResource = "detailed_stats_steps"

    /// Active Days label (detailed_stats_active_days)
    static let detailedStatsActiveDays: LocalizedStringResource = "detailed_stats_active_days"

    /// Items Collected label (detailed_stats_items)
    static let detailedStatsItems: LocalizedStringResource = "detailed_stats_items"

    /// Buildings Owned label (detailed_stats_buildings)
    static let detailedStatsBuildings: LocalizedStringResource = "detailed_stats_buildings"

    /// Storage Capacity label (detailed_stats_storage)
    static let detailedStatsStorage: LocalizedStringResource = "detailed_stats_storage"

    // MARK: - Profile View Detailed Stats

    /// View Detailed Stats button (profile_view_detailed_stats)
    static let profileViewDetailedStats: LocalizedStringResource = "profile_view_detailed_stats"

    // MARK: - Privacy Policy (86 keys)

    /// 隐私政策主标题 (privacy_title)
    static let privacyTitle: LocalizedStringResource = "privacy_title"

    /// 最后更新日期 (privacy_last_updated)
    static let privacyLastUpdated: LocalizedStringResource = "privacy_last_updated"

    // Section 1: Introduction
    static let privacyS1Title: LocalizedStringResource = "privacy_s1_title"
    static let privacyS1P1: LocalizedStringResource = "privacy_s1_p1"
    static let privacyS1P2: LocalizedStringResource = "privacy_s1_p2"
    static let privacyS1P3: LocalizedStringResource = "privacy_s1_p3"
    static let privacyS1P4: LocalizedStringResource = "privacy_s1_p4"

    // Section 2: Information We Collect
    static let privacyS2Title: LocalizedStringResource = "privacy_s2_title"

    // Section 2.1: Personal & Account Data
    static let privacyS2_1Title: LocalizedStringResource = "privacy_s2_1_title"
    static let privacyS2_1Intro: LocalizedStringResource = "privacy_s2_1_intro"
    static let privacyS2_1B1: LocalizedStringResource = "privacy_s2_1_b1"
    static let privacyS2_1B2: LocalizedStringResource = "privacy_s2_1_b2"
    static let privacyS2_1B3: LocalizedStringResource = "privacy_s2_1_b3"
    static let privacyS2_1B4: LocalizedStringResource = "privacy_s2_1_b4"

    // Section 2.2: Location Data
    static let privacyS2_2Title: LocalizedStringResource = "privacy_s2_2_title"
    static let privacyS2_2Intro1: LocalizedStringResource = "privacy_s2_2_intro1"
    static let privacyS2_2Intro2: LocalizedStringResource = "privacy_s2_2_intro2"
    static let privacyS2_2B1: LocalizedStringResource = "privacy_s2_2_b1"
    static let privacyS2_2B2: LocalizedStringResource = "privacy_s2_2_b2"
    static let privacyS2_2NoteIntro: LocalizedStringResource = "privacy_s2_2_note_intro"
    static let privacyS2_2B3: LocalizedStringResource = "privacy_s2_2_b3"
    static let privacyS2_2B4: LocalizedStringResource = "privacy_s2_2_b4"
    static let privacyS2_2B5: LocalizedStringResource = "privacy_s2_2_b5"

    // Section 2.3: Gameplay & Financial Data
    static let privacyS2_3Title: LocalizedStringResource = "privacy_s2_3_title"
    static let privacyS2_3Intro: LocalizedStringResource = "privacy_s2_3_intro"
    static let privacyS2_3B1: LocalizedStringResource = "privacy_s2_3_b1"
    static let privacyS2_3B2: LocalizedStringResource = "privacy_s2_3_b2"
    static let privacyS2_3B3: LocalizedStringResource = "privacy_s2_3_b3"
    static let privacyS2_3B4: LocalizedStringResource = "privacy_s2_3_b4"
    static let privacyS2_3Note: LocalizedStringResource = "privacy_s2_3_note"

    // Section 2.4: Diagnostic & Technical Data
    static let privacyS2_4Title: LocalizedStringResource = "privacy_s2_4_title"
    static let privacyS2_4Intro: LocalizedStringResource = "privacy_s2_4_intro"
    static let privacyS2_4B1: LocalizedStringResource = "privacy_s2_4_b1"
    static let privacyS2_4B2: LocalizedStringResource = "privacy_s2_4_b2"
    static let privacyS2_4B3: LocalizedStringResource = "privacy_s2_4_b3"
    static let privacyS2_4Note: LocalizedStringResource = "privacy_s2_4_note"

    // Section 3: Legal Basis for Processing
    static let privacyS3Title: LocalizedStringResource = "privacy_s3_title"
    static let privacyS3Intro: LocalizedStringResource = "privacy_s3_intro"
    static let privacyS3B1: LocalizedStringResource = "privacy_s3_b1"
    static let privacyS3B2: LocalizedStringResource = "privacy_s3_b2"
    static let privacyS3B3: LocalizedStringResource = "privacy_s3_b3"
    static let privacyS3Note: LocalizedStringResource = "privacy_s3_note"

    // Section 4: How We Use Your Information
    static let privacyS4Title: LocalizedStringResource = "privacy_s4_title"
    static let privacyS4Intro: LocalizedStringResource = "privacy_s4_intro"
    static let privacyS4B1: LocalizedStringResource = "privacy_s4_b1"
    static let privacyS4B2: LocalizedStringResource = "privacy_s4_b2"
    static let privacyS4B3: LocalizedStringResource = "privacy_s4_b3"
    static let privacyS4B4: LocalizedStringResource = "privacy_s4_b4"
    static let privacyS4B5: LocalizedStringResource = "privacy_s4_b5"
    static let privacyS4Note: LocalizedStringResource = "privacy_s4_note"

    // Section 5: Data Storage & International Transfers
    static let privacyS5Title: LocalizedStringResource = "privacy_s5_title"
    static let privacyS5P1: LocalizedStringResource = "privacy_s5_p1"
    static let privacyS5P2: LocalizedStringResource = "privacy_s5_p2"
    static let privacyS5P3: LocalizedStringResource = "privacy_s5_p3"

    // Section 6: Data Retention
    static let privacyS6Title: LocalizedStringResource = "privacy_s6_title"
    static let privacyS6Intro: LocalizedStringResource = "privacy_s6_intro"
    static let privacyS6B1: LocalizedStringResource = "privacy_s6_b1"
    static let privacyS6B2: LocalizedStringResource = "privacy_s6_b2"

    // Section 7: Data Sharing & Third Parties
    static let privacyS7Title: LocalizedStringResource = "privacy_s7_title"
    static let privacyS7P1: LocalizedStringResource = "privacy_s7_p1"
    static let privacyS7P2: LocalizedStringResource = "privacy_s7_p2"
    static let privacyS7B1: LocalizedStringResource = "privacy_s7_b1"
    static let privacyS7B2: LocalizedStringResource = "privacy_s7_b2"
    static let privacyS7Note: LocalizedStringResource = "privacy_s7_note"

    // Section 8: Your Rights
    static let privacyS8Title: LocalizedStringResource = "privacy_s8_title"
    static let privacyS8Intro: LocalizedStringResource = "privacy_s8_intro"
    static let privacyS8B1: LocalizedStringResource = "privacy_s8_b1"
    static let privacyS8B2: LocalizedStringResource = "privacy_s8_b2"
    static let privacyS8B3: LocalizedStringResource = "privacy_s8_b3"
    static let privacyS8B4: LocalizedStringResource = "privacy_s8_b4"
    static let privacyS8B5: LocalizedStringResource = "privacy_s8_b5"
    static let privacyS8DeleteVia: LocalizedStringResource = "privacy_s8_delete_via"
    static let privacyS8DeletePath: LocalizedStringResource = "privacy_s8_delete_path"
    static let privacyS8Irreversible: LocalizedStringResource = "privacy_s8_irreversible"
    static let privacyS8Contact: LocalizedStringResource = "privacy_s8_contact"

    // Section 9: Children's Privacy
    static let privacyS9Title: LocalizedStringResource = "privacy_s9_title"
    static let privacyS9P1: LocalizedStringResource = "privacy_s9_p1"
    static let privacyS9P2: LocalizedStringResource = "privacy_s9_p2"
    static let privacyS9P3: LocalizedStringResource = "privacy_s9_p3"

    // Section 10: Changes to This Policy
    static let privacyS10Title: LocalizedStringResource = "privacy_s10_title"
    static let privacyS10P1: LocalizedStringResource = "privacy_s10_p1"
    static let privacyS10P2: LocalizedStringResource = "privacy_s10_p2"
    static let privacyS10P3: LocalizedStringResource = "privacy_s10_p3"

    // Section 11: Contact
    static let privacyS11Title: LocalizedStringResource = "privacy_s11_title"
    static let privacyS11Intro: LocalizedStringResource = "privacy_s11_intro"
    static let privacyS11Name: LocalizedStringResource = "privacy_s11_name"

    // MARK: - Key Strings (for statusKey parameters)

    /// 仅需 key 字符串（如 statusKey）时使用
    enum Key {
        static let insufficientResources = "building_resources_insufficient"
        static let maxBuildingsReached = "building_max_reached"
        static let commonError = "common_error"
    }
}
