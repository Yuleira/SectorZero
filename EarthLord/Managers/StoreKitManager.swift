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
    // Subscriptions — Monthly
    case scavengerMonthly = "com.sectorzero.sub.scavenger.monthly"
    case pioneerMonthly = "com.sectorzero.sub.pioneer.monthly"
    case archonMonthly = "com.sectorzero.sub.archon.monthly"

    // Subscriptions — Yearly
    case scavengerYearly = "com.sectorzero.sub.scavenger.yearly"
    case pioneerYearly = "com.sectorzero.sub.pioneer.yearly"
    case archonYearly = "com.sectorzero.sub.archon.yearly"

    // Consumables — Aether Energy packs
    case energy5 = "com.sectorzero.energy.5"
    case energy20 = "com.sectorzero.energy.20"
    case energy50 = "com.sectorzero.energy.50"

    static var subscriptions: [StoreProductID] {
        [.scavengerMonthly, .scavengerYearly,
         .pioneerMonthly, .pioneerYearly,
         .archonMonthly, .archonYearly]
    }

    static var energyPacks: [StoreProductID] {
        [.energy5, .energy20, .energy50]
    }

    static var allProductIDs: Set<String> {
        Set(allCases.map { $0.rawValue })
    }

    /// Amount of energy granted by this product
    var energyAmount: Int? {
        switch self {
        case .energy5: return 5
        case .energy20: return 20
        case .energy50: return 50
        default: return nil
        }
    }

    /// Get the membership tier for this subscription product
    var tier: MembershipTier? {
        switch self {
        case .scavengerMonthly, .scavengerYearly: return .scavenger
        case .pioneerMonthly, .pioneerYearly: return .pioneer
        case .archonMonthly, .archonYearly: return .archon
        default: return nil
        }
    }

    /// Whether this is a yearly subscription
    var isYearly: Bool {
        switch self {
        case .scavengerYearly, .pioneerYearly, .archonYearly: return true
        default: return false
        }
    }

    /// Get monthly product ID for the same tier
    var monthlyCounterpart: StoreProductID? {
        switch self {
        case .scavengerYearly: return .scavengerMonthly
        case .pioneerYearly: return .pioneerMonthly
        case .archonYearly: return .archonMonthly
        default: return nil
        }
    }

    /// Get yearly product ID for the same tier
    var yearlyCounterpart: StoreProductID? {
        switch self {
        case .scavengerMonthly: return .scavengerYearly
        case .pioneerMonthly: return .pioneerYearly
        case .archonMonthly: return .archonYearly
        default: return nil
        }
    }

    /// Monthly product IDs (for grouping in UI)
    static var monthlySubscriptions: [StoreProductID] {
        [.scavengerMonthly, .pioneerMonthly, .archonMonthly]
    }

    /// Yearly product IDs
    static var yearlySubscriptions: [StoreProductID] {
        [.scavengerYearly, .pioneerYearly, .archonYearly]
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

    var maxTerritories: Int {
        switch self {
        case .free: return 3
        case .scavenger: return 5
        case .pioneer: return 10
        case .archon: return 25
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

    /// Consumable products
    @Published private(set) var consumableProducts: [Product] = []

    /// Set of purchased product IDs (for entitlement checking)
    @Published private(set) var purchasedProductIDs: Set<String> = []

    /// Current membership tier
    @Published private(set) var currentMembershipTier: MembershipTier = .free

    /// Subscription expiration/renewal date
    @Published private(set) var subscriptionExpirationDate: Date?

    /// Aether Energy balance (AI scan charges)
    @Published private(set) var aetherEnergy: Int = 0

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message for UI display
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    /// Archon tier grants unlimited AI scans
    var isInfiniteEnergyEnabled: Bool {
        currentMembershipTier >= .archon
    }

    /// Daily energy grant amount by tier (Free=3, Scavenger=5, Pioneer=10, Archon=infinite)
    var dailyEnergyAmount: Int {
        switch currentMembershipTier {
        case .free: return 3
        case .scavenger: return 5
        case .pioneer: return 10
        case .archon: return 0 // Archon has infinite energy, no grant needed
        }
    }

    /// Storage limit based on subscription tier
    var currentStorageLimit: Int {
        switch currentMembershipTier {
        case .free: return 100
        case .scavenger: return 150
        case .pioneer: return 300
        case .archon: return 600
        }
    }

    // MARK: - Private Properties

    private var transactionListener: Task<Void, Error>?

    /// Last date daily energy was granted
    private var lastEnergyGrantDate: Date?

    // MARK: - Initialization

    private init() {
        print("💰 [StoreKit] Initializing StoreKitManager...")
        startTransactionListener()
        Task { await logEnvironment() }
    }

    /// Log current StoreKit environment (Xcode local vs Sandbox) for real-device debugging
    private func logEnvironment() async {
        var env: String = "unknown (no transactions yet)"
        for await result in Transaction.all {
            if case .verified(let t) = result {
                env = t.environment.rawValue
                break
            }
        }
        print("🛒 [StoreKit] Current environment is: \(env)")
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
            await updatePurchasedProducts()      // recalculate tier (handles downgrade)
            await syncEntitlementsWithSupabase()  // sync recalculated state
            await transaction.finish()

        case .unverified(let transaction, let error):
            print("💰 [StoreKit] Transaction verification failed: \(transaction.productID), error: \(error)")
        }
    }

    // MARK: - Fetch Products

    /// Fetch all products from the App Store
    func fetchProducts() async {
        guard !isLoading else {
            print("🛒 [StoreKit] fetchProducts skipped — already loading")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let requestedIDs = StoreProductID.allProductIDs
        print("🛒 [StoreKit] Requesting \(requestedIDs.count) product IDs: \(requestedIDs)")

        do {
            let fetchedProducts = try await Product.products(for: requestedIDs)

            print("🛒 [StoreKit] Fetched \(fetchedProducts.count) products")

            if fetchedProducts.isEmpty {
                print("🛒 [StoreKit] ⚠️ 0 products returned. Ensure Products.storekit is set in Scheme > Run > Options > StoreKit Configuration")
            }

            for p in fetchedProducts {
                print("🛒 [StoreKit]   → \(p.id) | \(p.displayName) | \(p.displayPrice) | type=\(p.type)")
            }

            // Store all products sorted by price
            products = fetchedProducts.sorted { $0.price < $1.price }

            // Categorize products by type
            subscriptionProducts = fetchedProducts
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }

            consumableProducts = fetchedProducts
                .filter { $0.type == .consumable }

            print("🛒 [StoreKit] Categorized — Subs: \(subscriptionProducts.count), Consumable: \(consumableProducts.count)")

            // Update current entitlements (handles expiry/downgrade)
            await updatePurchasedProducts()
            // Sync to Supabase when tier may have changed (e.g. empty entitlements → tier 0)
            await syncEntitlementsWithSupabase()

        } catch {
            errorMessage = error.localizedDescription
            print("🛒 [StoreKit] ❌ Error fetching products: \(error)")
        }
    }

    // MARK: - Refresh Store

    /// Manual refresh: sync with App Store and refetch products. Use when real device has cached state.
    func refreshStore() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            print("🛒 [StoreKit] AppStore.sync completed")
            await updatePurchasedProducts()
            isLoading = false
            await fetchProducts()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("🛒 [StoreKit] Refresh error: \(error)")
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
        } else if let storeProduct = StoreProductID(rawValue: productID),
                  let energyAmount = storeProduct.energyAmount {
            // Consumable: add Aether Energy
            addAetherEnergy(energyAmount)
            print("💰 [StoreKit] Aether Energy balance updated to: \(aetherEnergy) (+\(energyAmount))")
        }

        // Sync with Supabase
        await syncEntitlementsWithSupabase()
    }

    /// Get membership tier for a product ID
    private func membershipTier(for productID: String) -> MembershipTier? {
        guard let storeProduct = StoreProductID(rawValue: productID) else { return nil }
        return storeProduct.tier
    }

    // MARK: - Aether Energy

    /// Attempt to consume 1 Aether Energy for an AI scan.
    /// Returns true if deduction succeeded (Archon bypasses, or balance > 0 and deducted).
    func consumeAetherEnergy() -> Bool {
        if isInfiniteEnergyEnabled {
            print("⚡ [Energy] Infinite energy (Archon) — no deduction")
            return true
        }
        guard aetherEnergy > 0 else {
            print("⚡ [Energy] Insufficient energy: \(aetherEnergy)")
            return false
        }
        aetherEnergy -= 1
        print("⚡ [Energy] Consumed 1 energy, remaining: \(aetherEnergy)")
        Task { await syncEntitlementsWithSupabase() }
        return true
    }

    /// Add Aether Energy units
    func addAetherEnergy(_ amount: Int) {
        aetherEnergy += amount
        print("⚡ [Energy] Added \(amount) energy, total: \(aetherEnergy)")
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

    /// Recompute subscription status from Transaction.currentEntitlements and sync to Supabase.
    /// Call on launch or when entitlements may have changed (e.g. after expiry, refund).
    /// If currentEntitlements is empty, tier is set to .free and membership_tier 0 is synced.
    func updateSubscriptionStatus() async {
        await updatePurchasedProducts()
        await syncEntitlementsWithSupabase()
    }

    /// Update the set of purchased products from current entitlements
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var highestTier: MembershipTier = .free
        var expirationDate: Date? = nil

        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            purchased.insert(transaction.productID)

            // Track highest subscription tier
            if let tier = membershipTier(for: transaction.productID), tier > highestTier {
                highestTier = tier
                expirationDate = transaction.expirationDate
            }
        }

        purchasedProductIDs = purchased
        currentMembershipTier = highestTier
        subscriptionExpirationDate = expirationDate

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
                let aether_energy: Int
                let last_energy_grant_date: String?
                let updated_at: String
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            let update = IAPUpdate(
                membership_tier: currentMembershipTier.rawValue,
                aether_energy: aetherEnergy,
                last_energy_grant_date: lastEnergyGrantDate.map { dateFormatter.string(from: $0) },
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
            print("   - Energy: \(aetherEnergy)")

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
                let aether_energy: Int?
                let last_energy_grant_date: String?
            }

            let response: [ProfileIAP] = try await supabase
                .from("player_profiles")
                .select("membership_tier, aether_energy, last_energy_grant_date")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let profile = response.first {
                currentMembershipTier = MembershipTier(rawValue: profile.membership_tier ?? 0) ?? .free
                aetherEnergy = profile.aether_energy ?? 0

                // Parse grant dates
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                lastEnergyGrantDate = profile.last_energy_grant_date.flatMap { dateFormatter.date(from: $0) }

                print("💰 [StoreKit] Loaded entitlements from Supabase")
                print("   - Tier: \(currentMembershipTier)")
                print("   - Energy: \(aetherEnergy)")
            }

            // Check and grant daily energy
            await checkAndGrantDailyEnergy()

        } catch {
            print("💰 [StoreKit] Load entitlements error: \(error)")
        }
    }

    // MARK: - Daily Grants

    /// Check and grant daily energy regeneration.
    /// Free=3, Scavenger=5, Pioneer=10, Archon=infinite (no grant needed)
    private func checkAndGrantDailyEnergy() async {
        // Archon has infinite energy, skip grant
        guard !isInfiniteEnergyEnabled else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // Check if already granted today
        if let lastGrant = lastEnergyGrantDate,
           Calendar.current.isDate(lastGrant, inSameDayAs: today) {
            print("⚡ [Daily] Energy already granted today")
            return
        }

        let amount = dailyEnergyAmount
        guard amount > 0 else { return }

        addAetherEnergy(amount)
        lastEnergyGrantDate = today
        print("⚡ [Daily] Granted \(amount) daily energy (tier: \(currentMembershipTier))")

        await syncEntitlementsWithSupabase()
    }

    // MARK: - Helpers

    /// Check if a product has been purchased
    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    /// Check if current plan matches a product (checks both monthly and yearly for same tier)
    func isCurrentPlan(_ product: Product) -> Bool {
        guard let storeProduct = StoreProductID(rawValue: product.id),
              let tier = storeProduct.tier else { return false }
        return tier == currentMembershipTier
    }

    /// Get product by ID
    func product(for id: StoreProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Human-readable subscription date: "Renews on Feb 28" or "Expires in 5 days" / "Subscription Expired"
    var formattedExpirationDate: String? {
        guard let date = subscriptionExpirationDate else { return nil }
        let now = Date()
        if date <= now {
            return String(localized: LocalizedString.subscriptionExpired)
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        if days <= 7 {
            return String(format: String(localized: LocalizedString.subscriptionExpiresInDaysFormat), days)
        }
        return String(format: String(localized: LocalizedString.subscriptionRenewsOn),
                      date.formatted(date: .abbreviated, time: .omitted))
    }

    /// Filter products to energy packs only
    var energyPackProducts: [Product] {
        let energyIDs = Set(StoreProductID.energyPacks.map { $0.rawValue })
        return consumableProducts
            .filter { energyIDs.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    /// Get monthly subscription products (one per tier, sorted by price)
    var monthlySubscriptionProducts: [Product] {
        let monthlyIDs = Set(StoreProductID.monthlySubscriptions.map { $0.rawValue })
        return subscriptionProducts
            .filter { monthlyIDs.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    /// Get yearly subscription products (one per tier, sorted by price)
    var yearlySubscriptionProducts: [Product] {
        let yearlyIDs = Set(StoreProductID.yearlySubscriptions.map { $0.rawValue })
        return subscriptionProducts
            .filter { yearlyIDs.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Simulate a purchase for testing (debug only)
    func simulatePurchase(_ productID: StoreProductID) async {
        print("💰 [StoreKit] DEBUG: Simulating purchase of \(productID.rawValue)")

        purchasedProductIDs.insert(productID.rawValue)

        if let tier = productID.tier {
            currentMembershipTier = tier
        } else if let energyAmount = productID.energyAmount {
            addAetherEnergy(energyAmount)
        }

        await syncEntitlementsWithSupabase()
    }

    /// Reset all entitlements for testing (debug only)
    func resetEntitlements() {
        print("💰 [StoreKit] DEBUG: Resetting all entitlements")
        purchasedProductIDs.removeAll()
        currentMembershipTier = .free
        aetherEnergy = 0
    }
    #endif
}
