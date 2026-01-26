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

    // MARK: - Tabs (4 keys)

    /// 地图 (tab_map)
    static let tabMap: LocalizedStringResource = "tab_map"

    /// 领地 (tab_territory)
    static let tabTerritory: LocalizedStringResource = "tab_territory"

    /// 资源 (tab_resources)
    static let tabResources: LocalizedStringResource = "tab_resources"

    /// 个人 (tab_profile)
    static let tabProfile: LocalizedStringResource = "tab_profile"

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

    // MARK: - Key Strings (for statusKey parameters)

    /// 仅需 key 字符串（如 statusKey）时使用
    enum Key {
        static let insufficientResources = "building_resources_insufficient"
        static let maxBuildingsReached = "building_max_reached"
        static let commonError = "common_error"
    }
}
