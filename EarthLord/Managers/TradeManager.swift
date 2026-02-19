//
//  TradeManager.swift
//  EarthLord
//
//  交易系统管理器
//  负责玩家之间的物品交易逻辑
//

import Foundation
import Supabase
import Combine

/// 交易错误类型
enum TradeError: LocalizedError {
    case notAuthenticated
    case insufficientItems(itemId: String, needed: Int, available: Int)
    case offerNotFound
    case offerNotActive
    case offerExpired
    case cannotAcceptOwnOffer
    case notOfferOwner
    case alreadyRated
    case invalidParameters
    case databaseError(String)
    case networkError
    case supabaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "error_not_logged_in")
        case .insufficientItems(let itemId, let needed, let available):
            return String(format: String(localized: "trade_error_insufficient_items"), itemId, needed, available)
        case .offerNotFound:
            return String(localized: "trade_error_offer_not_found")
        case .offerNotActive:
            return String(localized: "trade_error_offer_not_active")
        case .offerExpired:
            return String(localized: "trade_error_offer_expired")
        case .cannotAcceptOwnOffer:
            return String(localized: "trade_error_cannot_accept_own_offer")
        case .notOfferOwner:
            return String(localized: "trade_error_not_offer_owner")
        case .alreadyRated:
            return String(localized: "trade_error_already_rated")
        case .invalidParameters:
            return String(localized: "trade_error_invalid_parameters")
        case .databaseError(let message):
            return String(format: String(localized: "error_database_format"), message)
        case .networkError:
            return NSLocalizedString("error_network_connection_failed", comment: "")
        case .supabaseNotConfigured:
            return NSLocalizedString("error_service_unavailable", comment: "")
        }
    }
}

// MARK: - RPC Parameter Structs

  /// 交易系统管理器
@MainActor
class TradeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TradeManager()

    // MARK: - Published Properties

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（市场）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史列表
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let supabase = SupabaseService.shared.client
    private let authManager = AuthManager.shared
    private let inventoryManager = InventoryManager.shared

    // MARK: - Initialization

    private init() {
        debugLog("🔄 [TradeManager] Initialized")
    }

    // MARK: - Public Methods

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表
    ///   - requestingItems: 需要的物品列表
    ///   - validityHours: 有效期（小时数，默认24小时）
    ///   - message: 留言（可选）
    /// - Returns: 创建成功的挂单ID
    func createTradeOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        validityHours: Int = 24,
        message: String? = nil
    ) async throws -> String {
        debugLog("📦 [TradeManager] Creating trade offer...")

        // 1. 验证用户登录
        guard authManager.isAuthenticated else {
            throw TradeError.notAuthenticated
        }

        // 2. 验证参数
        guard !offeringItems.isEmpty, !requestingItems.isEmpty else {
            throw TradeError.invalidParameters
        }

        // 3. 构建参数
        let params = CreateTradeOfferParams(
            p_offering_items: offeringItems,
            p_requesting_items: requestingItems,
            p_validity_hours: validityHours,
            p_message: message
        )

        do {
            // 4. 调用数据库函数创建挂单
            debugLog("🔧 [TradeManager] Calling RPC: create_trade_offer")
            debugLog("   Parameters: offering=\(offeringItems.count) items, requesting=\(requestingItems.count) items")

            let response = try await supabase.rpc(
                "create_trade_offer",
                params: params
            ).execute()

            debugLog("✅ [TradeManager] RPC call succeeded")

            // 5. 解析返回的挂单ID
            guard let offerId = String(data: response.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\""))) else {
                throw TradeError.databaseError("Failed to parse offer ID")
            }

            debugLog("✅ [TradeManager] Trade offer created: \(offerId)")

            // 6. 刷新我的挂单列表
            await loadMyOffers()

            // 7. 刷新库存（物品已被锁定）
            await inventoryManager.loadItems()

            return offerId

        } catch let error as PostgrestError {
            // 解析数据库错误
            debugLog("❌ [TradeManager] PostgrestError caught")
            debugLog("   Code: \(error.code ?? "unknown")")
            debugLog("   Message: \(error.message)")

            let message = error.message

            // 检查是否是 RPC 函数不存在的错误
            if message.contains("function") && message.contains("does not exist") {
                debugLog("   ⚠️ RPC function 'create_trade_offer' does not exist in database")
                throw TradeError.databaseError("交易系统未初始化。\n请执行数据库迁移：\n1. 运行 007_trade_system.sql\n2. 运行 008_inventory_helper_functions.sql\n\nTrade system not initialized.\nPlease run database migrations:\n1. Execute 007_trade_system.sql\n2. Execute 008_inventory_helper_functions.sql")
            }

            if message.contains("Insufficient items") {
                // 提取物品不足的信息
                debugLog("   ℹ️ User has insufficient items")
                throw TradeError.databaseError(message)
            }

            throw TradeError.databaseError(error.message)

        } catch let error as URLError {
            // 网络错误
            debugLog("❌ [TradeManager] URLError caught")
            debugLog("   Error code: \(error.code.rawValue)")
            debugLog("   Description: \(error.localizedDescription)")
            debugLog("   Failing URL: \(error.failingURL?.absoluteString ?? "unknown")")

            throw TradeError.networkError

        } catch {
            // 其他未知错误
            debugLog("❌ [TradeManager] Unknown error caught")
            debugLog("   Type: \(type(of: error))")
            debugLog("   Description: \(error.localizedDescription)")
            debugLog("   Debug: \(error)")

            // 如果错误描述包含网络相关关键词，归类为网络错误
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("network") || errorDesc.contains("connection") ||
               errorDesc.contains("hostname") || errorDesc.contains("internet") ||
               errorDesc.contains("could not connect") || errorDesc.contains("timed out") {
                throw TradeError.networkError
            }

            throw error
        }
    }

    /// 接受交易挂单
    /// - Parameter offerId: 挂单ID
    /// - Returns: 交易结果（包含历史记录ID和交换的物品）
    func acceptTradeOffer(offerId: String) async throws -> (historyId: String, offeredItems: [TradeItem], receivedItems: [TradeItem]) {
        debugLog("🤝 [TradeManager] Accepting trade offer: \(offerId)")

        // 1. 验证用户登录
        guard authManager.isAuthenticated else {
            throw TradeError.notAuthenticated
        }

        do {
            // 2. 调用数据库函数接受挂单
            let params = AcceptTradeOfferParams(p_offer_id: offerId)
            let response = try await supabase.rpc(
                "accept_trade_offer",
                params: params
            ).execute()

            // 3. 解析返回结果
            struct AcceptResult: Codable {
                let success: Bool
                let historyId: String
                let offeredItems: [TradeItem]
                let receivedItems: [TradeItem]

                enum CodingKeys: String, CodingKey {
                    case success
                    case historyId = "history_id"
                    case offeredItems = "offered_items"
                    case receivedItems = "received_items"
                }
            }

            let result = try JSONDecoder().decode(AcceptResult.self, from: response.data)

            debugLog("✅ [TradeManager] Trade accepted successfully")
            debugLog("   📜 History ID: \(result.historyId)")
            debugLog("   📦 Offered: \(result.offeredItems.count) items")
            debugLog("   📥 Received: \(result.receivedItems.count) items")

            // 4. 刷新相关数据
            await loadAvailableOffers()
            await loadTradeHistory()
            await inventoryManager.loadItems()

            return (result.historyId, result.offeredItems, result.receivedItems)

        } catch let error as PostgrestError {
            // 解析具体错误
            let message = error.message
            if message.contains("not found") {
                throw TradeError.offerNotFound
            } else if message.contains("not active") {
                throw TradeError.offerNotActive
            } else if message.contains("expired") {
                throw TradeError.offerExpired
            } else if message.contains("your own") {
                throw TradeError.cannotAcceptOwnOffer
            } else if message.contains("Insufficient items") {
                throw TradeError.databaseError(message)
            }
            debugLog("❌ [TradeManager] Database error: \(error)")
            throw TradeError.databaseError(error.message)
        } catch {
            debugLog("❌ [TradeManager] Error accepting trade offer: \(error)")
            throw error
        }
    }

    /// 取消交易挂单
    /// - Parameter offerId: 挂单ID
    func cancelTradeOffer(offerId: String) async throws {
        debugLog("❌ [TradeManager] Cancelling trade offer: \(offerId)")

        // 1. 验证用户登录
        guard authManager.isAuthenticated else {
            throw TradeError.notAuthenticated
        }

        do {
            // 2. 调用数据库函数取消挂单
            let params = CancelTradeOfferParams(p_offer_id: offerId)
            let _ = try await supabase.rpc(
                "cancel_trade_offer",
                params: params
            ).execute()

            debugLog("✅ [TradeManager] Trade offer cancelled successfully")

            // 3. 刷新相关数据
            await loadMyOffers()
            await inventoryManager.loadItems() // 物品已退回

        } catch let error as PostgrestError {
            // 解析具体错误
            let message = error.message
            if message.contains("not found") {
                throw TradeError.offerNotFound
            } else if message.contains("only cancel your own") {
                throw TradeError.notOfferOwner
            } else if message.contains("only cancel active") {
                throw TradeError.offerNotActive
            }
            debugLog("❌ [TradeManager] Database error: \(error)")
            throw TradeError.databaseError(error.message)
        } catch {
            debugLog("❌ [TradeManager] Error cancelling trade offer: \(error)")
            throw error
        }
    }

    /// 加载我的挂单
    /// - Parameter status: 可选，过滤指定状态的挂单
    func loadMyOffers(status: TradeOfferStatus? = nil) async {
        debugLog("📋 [TradeManager] Loading my offers...")

        guard authManager.isAuthenticated else {
            debugLog("⚠️ [TradeManager] Not authenticated")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let params = GetMyTradeOffersParams(p_status: status?.rawValue)
            let response = try await supabase.rpc(
                "get_my_trade_offers",
                params: params
            ).execute()

            let offers = try JSONDecoder().decode([TradeOffer].self, from: response.data)
            self.myOffers = offers
            debugLog("✅ [TradeManager] Loaded \(offers.count) my offers")

        } catch {
            debugLog("❌ [TradeManager] Error loading my offers: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// 加载可接受的挂单（交易市场）
    /// - Parameters:
    ///   - limit: 限制数量（默认50）
    ///   - offset: 偏移量（默认0，用于分页）
    func loadAvailableOffers(limit: Int = 50, offset: Int = 0) async {
        debugLog("🛒 [TradeManager] Loading available offers...")

        guard authManager.isAuthenticated else {
            debugLog("⚠️ [TradeManager] Not authenticated")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let params = GetAvailableTradeOffersParams(
                p_limit: limit,
                p_offset: offset
            )
            let response = try await supabase.rpc(
                "get_available_trade_offers",
                params: params
            ).execute()

            let offers = try JSONDecoder().decode([TradeOffer].self, from: response.data)
            self.availableOffers = offers

            debugLog("✅ [TradeManager] Loaded \(offers.count) available offers")

        } catch {
            debugLog("❌ [TradeManager] Error loading available offers: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        debugLog("📜 [TradeManager] Loading trade history...")

        guard authManager.isAuthenticated else {
            debugLog("⚠️ [TradeManager] Not authenticated")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await supabase.rpc(
                "get_my_trade_history"
            ).execute()

            let history = try JSONDecoder().decode([TradeHistory].self, from: response.data)
            self.tradeHistory = history

            debugLog("✅ [TradeManager] Loaded \(history.count) trade history records")

        } catch {
            debugLog("❌ [TradeManager] Error loading trade history: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// 评价交易
    /// - Parameters:
    ///   - tradeHistoryId: 交易历史ID
    ///   - rating: 评分（1-5）
    ///   - comment: 评语（可选）
    func rateTrade(tradeHistoryId: String, rating: Int, comment: String? = nil) async throws {
        debugLog("⭐ [TradeManager] Rating trade: \(tradeHistoryId), rating: \(rating)")

        // 1. 验证用户登录
        guard authManager.isAuthenticated else {
            throw TradeError.notAuthenticated
        }

        // 2. 验证评分范围
        let validRating = max(1, min(5, rating))

        do {
            // 3. 调用数据库函数评价交易
            // Convert the tradeHistoryId string to UUID
            guard let tradeUUID = UUID(uuidString: tradeHistoryId) else {
                throw TradeError.invalidParameters
            }
            
            // Create properly typed Encodable params
            let params = RateTradeParams(
                p_trade_id: tradeUUID,
                p_rating: validRating,
                p_comment: comment
            )

            let _ = try await supabase.rpc(
                "rate_trade",
                params: params
            ).execute()
            debugLog("✅ [TradeManager] Trade rated successfully")
            // 4. 刷新交易历史
            await loadTradeHistory()

        } catch let error as PostgrestError {
            // 解析具体错误
            let message = error.message
            if message.contains("not found") {
                throw TradeError.offerNotFound
            } else if message.contains("already rated") {
                throw TradeError.alreadyRated
            } else if message.contains("not a participant") {
                throw TradeError.notOfferOwner
            }
            debugLog("❌ [TradeManager] Database error: \(error)")
            throw TradeError.databaseError(error.message)
        } catch {
            debugLog("❌ [TradeManager] Error rating trade: \(error)")
            throw error
        }
    }

    /// 处理过期挂单（定时任务调用或手动触发）
    func processExpiredOffers() async -> Int {
        debugLog("🕒 [TradeManager] Processing expired offers...")

        guard authManager.isAuthenticated else {
            debugLog("⚠️ [TradeManager] Not authenticated")
            return 0
        }

        do {
            let response = try await supabase.rpc("process_expired_offers").execute()

            // 解析处理的挂单数量
            if let countString = String(data: response.data, encoding: .utf8),
               let count = Int(countString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                debugLog("✅ [TradeManager] Processed \(count) expired offers")

                // 刷新我的挂单列表
                await loadMyOffers()
                await inventoryManager.loadItems()

                return count
            }

            return 0

        } catch {
            debugLog("❌ [TradeManager] Error processing expired offers: \(error)")
            return 0
        }
    }

    // MARK: - Helper Methods

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 获取物品显示名称（辅助方法）
    /// - Parameter itemId: 物品ID
    /// - Returns: 本地化的物品名称
    func getItemDisplayName(for itemId: String) -> String {
        return inventoryManager.resourceDisplayName(for: itemId)
    }

    /// 获取物品图标名称（辅助方法）
    /// - Parameter itemId: 物品ID
    /// - Returns: SF Symbol 图标名称
    func getItemIconName(for itemId: String) -> String {
        return inventoryManager.resourceIconName(for: itemId)
    }
}
