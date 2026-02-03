//
//  StoreKitManager.swift
//  EarthLord
//
//  StoreKit 2 IAP Manager for SectorZero
//  Handles purchases, subscriptions, and Supabase entitlement sync
//

import Foundation
import StoreKit
import Supabase
import Combine

// MARK: - Product Identifiers

/// Product identifiers matching Products.storekit configuration
enum StoreProductID: String, CaseIterable {
    // Subscriptions
    case scavenger = "com.sectorzero.sub.scavenger"
    case pioneer = "com.sectorzero.sub.pioneer"
    case archon = "com.sectorzero.sub.archon"

    // Non-consumables
    case storageLarge = "com.sectorzero.item.storage_large"

    // Consumables
    case shards100 = "com.sectorzero.shards.100"

    static var subscriptions: [StoreProductID] {
        [.scavenger, .pioneer, .archon]
    }

    static var allProductIDs: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

// MARK: - Membership Tier

/// Membership tier levels (synced with Supabase player_profiles.membership_tier)
enum MembershipTier: Int, Comparable {
    case free = 0
    case scavenger = 1
    case pioneer = 2
    case archon = 3

    static func < (lhs: MembershipTier, rhs: MembershipTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .free: return LocalizedString.tierFree
        case .scavenger: return LocalizedString.tierScavenger
        case .pioneer: return LocalizedString.tierPioneer
        case .archon: return LocalizedString.tierArchon
        }
    }
}

// MARK: - Store Errors

enum StoreError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    case networkError
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return String(localized: LocalizedString.storeVerificationFailed)
        case .purchaseFailed:
            return String(localized: LocalizedString.storePurchaseFailed)
        case .networkError:
            return String(localized: LocalizedString.storeNetworkError)
        case .notAuthenticated:
            return String(localized: LocalizedString.authLoginRequired)
        }
    }
}

// MARK: - StoreKitManager

/// Manages all In-App Purchase operations using StoreKit 2
@MainActor
final class StoreKitManager: ObservableObject {

    // MARK: - Singleton

    static let shared = StoreKitManager()

    // MARK: - Published Properties

    /// All loaded products
    @Published private(set) var products: [Product] = []

    /// Subscription products only (sorted by price)
    @Published private(set) var subscriptionProducts: [Product] = []

    /// Non-consumable products
    @Published private(set) var nonConsumableProducts: [Product] = []

    /// Consumable products
    @Published private(set) var consumableProducts: [Product] = []

    /// Set of purchased product IDs (for entitlement checking)
    @Published private(set) var purchasedProductIDs: Set<String> = []

    /// Current membership tier
    @Published private(set) var currentMembershipTier: MembershipTier = .free

    /// Aether Shards balance (consumable currency)
    @Published private(set) var shardsBalance: Int = 0

    /// Permanent unlocks (non-consumable product IDs)
    @Published private(set) var permanentUnlocks: [String] = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message for UI display
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var transactionListener: Task<Void, Error>?

    // MARK: - Initialization

    private init() {
        print("💰 [StoreKit] Initializing StoreKitManager...")
        startTransactionListener()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Transaction Listener

    /// Start listening for transaction updates in the background
    /// This handles transactions that occur outside the app (family sharing, renewals, etc.)
    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            print("💰 [StoreKit] Transaction listener started")
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }

    /// Handle incoming transaction update
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            print("💰 [StoreKit] Transaction update verified: \(transaction.productID)")
            await processTransaction(transaction)
            await transaction.finish()

        case .unverified(let transaction, let error):
            print("💰 [StoreKit] Transaction verification failed: \(transaction.productID), error: \(error)")
        }
    }

    // MARK: - Fetch Products

    /// Fetch all products from the App Store
    func fetchProducts() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedProducts = try await Product.products(for: StoreProductID.allProductIDs)

            // Store all products sorted by price
            products = fetchedProducts.sorted { $0.price < $1.price }

            // Categorize products by type
            subscriptionProducts = fetchedProducts
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }

            nonConsumableProducts = fetchedProducts
                .filter { $0.type == .nonConsumable }

            consumableProducts = fetchedProducts
                .filter { $0.type == .consumable }

            print("💰 [StoreKit] Loaded \(products.count) products:")
            print("   - Subscriptions: \(subscriptionProducts.count)")
            print("   - Non-consumables: \(nonConsumableProducts.count)")
            print("   - Consumables: \(consumableProducts.count)")

            // Update current entitlements
            await updatePurchasedProducts()

        } catch {
            errorMessage = error.localizedDescription
            print("💰 [StoreKit] Error fetching products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchase a product
    /// - Parameter product: The product to purchase
    /// - Returns: The transaction if successful, nil if cancelled or pending
    func purchase(_ product: Product) async throws -> Transaction? {
        guard !isLoading else { return nil }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("💰 [StoreKit] Purchase successful: \(product.id)")
                    await processTransaction(transaction)
                    await transaction.finish()
                    return transaction

                case .unverified(_, let error):
                    print("💰 [StoreKit] Transaction verification failed: \(error)")
                    throw StoreError.verificationFailed
                }

            case .userCancelled:
                print("💰 [StoreKit] User cancelled purchase")
                return nil

            case .pending:
                print("💰 [StoreKit] Purchase pending (Ask to Buy)")
                return nil

            @unknown default:
                print("💰 [StoreKit] Unknown purchase result")
                return nil
            }

        } catch {
            if error is StoreError {
                errorMessage = error.localizedDescription
                throw error
            } else {
                errorMessage = error.localizedDescription
                print("💰 [StoreKit] Purchase error: \(error)")
                throw StoreError.purchaseFailed
            }
        }
    }

    // MARK: - Process Transaction

    /// Process a verified transaction and update local state
    private func processTransaction(_ transaction: Transaction) async {
        let productID = transaction.productID
        print("💰 [StoreKit] Processing transaction: \(productID)")

        // Update purchased products set
        purchasedProductIDs.insert(productID)

        // Handle based on product type
        if let tier = membershipTier(for: productID) {
            // Subscription: update membership tier
            if tier > currentMembershipTier {
                currentMembershipTier = tier
                print("💰 [StoreKit] Membership tier updated to: \(tier)")
            }
        } else if productID == StoreProductID.storageLarge.rawValue {
            // Non-consumable: add to permanent unlocks
            if !permanentUnlocks.contains(productID) {
                permanentUnlocks.append(productID)
                print("💰 [StoreKit] Added permanent unlock: \(productID)")
            }
        } else if productID == StoreProductID.shards100.rawValue {
            // Consumable: add shards
            shardsBalance += 100
            print("💰 [StoreKit] Shards balance updated to: \(shardsBalance)")
        }

        // Sync with Supabase
        await syncEntitlementsWithSupabase()
    }

    /// Get membership tier for a product ID
    private func membershipTier(for productID: String) -> MembershipTier? {
        switch productID {
        case StoreProductID.scavenger.rawValue: return .scavenger
        case StoreProductID.pioneer.rawValue: return .pioneer
        case StoreProductID.archon.rawValue: return .archon
        default: return nil
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update purchased products
            await updatePurchasedProducts()

            // Sync with Supabase
            await syncEntitlementsWithSupabase()

            print("💰 [StoreKit] Restore completed successfully")

        } catch {
            errorMessage = error.localizedDescription
            print("💰 [StoreKit] Restore error: \(error)")
        }
    }

    /// Update the set of purchased products from current entitlements
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var highestTier: MembershipTier = .free

        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            purchased.insert(transaction.productID)

            // Track highest subscription tier
            if let tier = membershipTier(for: transaction.productID), tier > highestTier {
                highestTier = tier
            }

            // Track permanent unlocks
            if transaction.productID == StoreProductID.storageLarge.rawValue {
                if !permanentUnlocks.contains(transaction.productID) {
                    permanentUnlocks.append(transaction.productID)
                }
            }
        }

        purchasedProductIDs = purchased
        currentMembershipTier = highestTier

        print("💰 [StoreKit] Updated entitlements: \(purchased.count) items, tier: \(highestTier)")
    }

    // MARK: - Supabase Sync

    /// Sync current entitlements with Supabase player_profiles
    func syncEntitlementsWithSupabase() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("💰 [StoreKit] Cannot sync: not authenticated")
            return
        }

        do {
            // Prepare update payload
            struct IAPUpdate: Encodable {
                let membership_tier: Int
                let shards_balance: Int
                let permanent_unlocks: [String]
                let updated_at: String
            }

            let update = IAPUpdate(
                membership_tier: currentMembershipTier.rawValue,
                shards_balance: shardsBalance,
                permanent_unlocks: permanentUnlocks,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            // Update player_profiles
            try await supabase
                .from("player_profiles")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("💰 [StoreKit] Synced entitlements to Supabase")
            print("   - Tier: \(currentMembershipTier.rawValue)")
            print("   - Shards: \(shardsBalance)")
            print("   - Unlocks: \(permanentUnlocks)")

        } catch {
            print("💰 [StoreKit] Sync error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Load entitlements from Supabase (on app launch or login)
    func loadEntitlementsFromSupabase() async {
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("💰 [StoreKit] Cannot load: not authenticated")
            return
        }

        do {
            struct ProfileIAP: Decodable {
                let membership_tier: Int?
                let shards_balance: Int?
                let permanent_unlocks: [String]?
            }

            let response: [ProfileIAP] = try await supabase
                .from("player_profiles")
                .select("membership_tier, shards_balance, permanent_unlocks")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let profile = response.first {
                currentMembershipTier = MembershipTier(rawValue: profile.membership_tier ?? 0) ?? .free
                shardsBalance = profile.shards_balance ?? 0
                permanentUnlocks = profile.permanent_unlocks ?? []

                print("💰 [StoreKit] Loaded entitlements from Supabase")
                print("   - Tier: \(currentMembershipTier)")
                print("   - Shards: \(shardsBalance)")
                print("   - Unlocks: \(permanentUnlocks)")
            }

        } catch {
            print("💰 [StoreKit] Load entitlements error: \(error)")
        }
    }

    // MARK: - Helpers

    /// Check if a product has been purchased
    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    /// Check if user has a specific permanent unlock
    func hasUnlock(_ productID: String) -> Bool {
        permanentUnlocks.contains(productID)
    }

    /// Check if current plan matches a product
    func isCurrentPlan(_ product: Product) -> Bool {
        guard let tier = membershipTier(for: product.id) else { return false }
        return tier == currentMembershipTier
    }

    /// Get product by ID
    func product(for id: StoreProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Simulate a purchase for testing (debug only)
    func simulatePurchase(_ productID: StoreProductID) async {
        print("💰 [StoreKit] DEBUG: Simulating purchase of \(productID.rawValue)")

        purchasedProductIDs.insert(productID.rawValue)

        if let tier = membershipTier(for: productID.rawValue) {
            currentMembershipTier = tier
        } else if productID == .storageLarge {
            permanentUnlocks.append(productID.rawValue)
        } else if productID == .shards100 {
            shardsBalance += 100
        }

        await syncEntitlementsWithSupabase()
    }

    /// Reset all entitlements for testing (debug only)
    func resetEntitlements() {
        print("💰 [StoreKit] DEBUG: Resetting all entitlements")
        purchasedProductIDs.removeAll()
        currentMembershipTier = .free
        shardsBalance = 0
        permanentUnlocks.removeAll()
    }
    #endif
}
