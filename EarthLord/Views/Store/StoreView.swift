//
//  StoreView.swift
//  EarthLord
//
//  Main store UI for In-App Purchases
//  Supports context-aware navigation via StoreSection auto-scrolling
//

import SwiftUI
import StoreKit

// MARK: - Store Section

/// Sections of the store, used for context-aware deep-link navigation.
enum StoreSection: String, CaseIterable, Identifiable {
    case subscriptions
    case items
    case energy
    case coins
    case exchange

    var id: String { rawValue }
}

// MARK: - Resource Exchange Rates

struct ResourceExchangeRate {
    let resourceName: String
    let resourceIcon: String
    let resourceColor: Color
    let coinCost: Int
    let resourceAmount: Int
    /// The item_definitions category used when adding to inventory
    let category: String
}

/// Exchange rates: Aether Coins → Resources
let resourceExchangeRates: [ResourceExchangeRate] = [
    ResourceExchangeRate(resourceName: "Wood", resourceIcon: "leaf.fill", resourceColor: .brown, coinCost: 10, resourceAmount: 100, category: "material"),
    ResourceExchangeRate(resourceName: "Stone", resourceIcon: "mountain.2.fill", resourceColor: .gray, coinCost: 10, resourceAmount: 100, category: "material"),
    ResourceExchangeRate(resourceName: "Metal", resourceIcon: "gearshape.fill", resourceColor: .blue, coinCost: 15, resourceAmount: 50, category: "material"),
    ResourceExchangeRate(resourceName: "Fabric", resourceIcon: "tshirt.fill", resourceColor: .purple, coinCost: 10, resourceAmount: 80, category: "material"),
]

// MARK: - Store View

struct StoreView: View {
    /// Optional section to auto-scroll to on appear.
    var initialSection: StoreSection? = nil

    @ObservedObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreAlert = false
    @State private var showPurchaseSuccessAlert = false
    @State private var showFetchErrorAlert = false
    @State private var restoreMessage: String = ""
    @State private var showInsufficientCoinsAlert = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if storeManager.isLoading && storeManager.products.isEmpty {
                loadingView
            } else if storeManager.products.isEmpty {
                emptyStateView
            } else {
                productsList
            }
        }
        .navigationTitle(Text(LocalizedString.storeTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await storeManager.refreshStore()
                            if storeManager.errorMessage != nil {
                                showFetchErrorAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .disabled(storeManager.isLoading)

                    Button {
                        Task {
                            await storeManager.restorePurchases()
                            restoreMessage = storeManager.errorMessage ?? String(localized: LocalizedString.storeRestoreCompleted)
                            showRestoreAlert = true
                        }
                    } label: {
                        Text(LocalizedString.storeRestorePurchases)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .disabled(storeManager.isLoading)
                }
            }
        }
        .task {
            await storeManager.loadEntitlementsFromSupabase()
            await storeManager.updateSubscriptionStatus()
            if storeManager.products.isEmpty {
                await storeManager.fetchProducts()
                if storeManager.errorMessage != nil && storeManager.products.isEmpty {
                    showFetchErrorAlert = true
                }
            }
        }
        .alert(Text(LocalizedString.storePurchaseSuccessful), isPresented: $showPurchaseSuccessAlert) {
            Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
        }
        .alert(Text(LocalizedString.storeRestorePurchases), isPresented: $showRestoreAlert) {
            Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        .alert(Text(LocalizedString.commonError), isPresented: $showFetchErrorAlert) {
            Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
            Button(String(localized: LocalizedString.storeRefresh), role: .none) {
                Task {
                    await storeManager.refreshStore()
                    if storeManager.errorMessage != nil {
                        showFetchErrorAlert = true
                    }
                }
            }
        } message: {
            Text(storeManager.errorMessage ?? String(localized: LocalizedString.storeNetworkError))
        }
        .alert(Text(LocalizedString.insufficientResources), isPresented: $showInsufficientCoinsAlert) {
            Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
        } message: {
            Text(LocalizedString.storeInsufficientCoins)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text(LocalizedString.storeLoadingProducts)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text(LocalizedString.storeNoProducts)
                .foregroundColor(ApocalypseTheme.textSecondary)

            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    await storeManager.fetchProducts()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(LocalizedString.refresh)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Products List (ScrollViewReader + auto-scroll)

    private var productsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 24) {
                    // Current Tier Badge
                    currentTierBadge

                    // Subscriptions
                    if !storeManager.subscriptionProducts.isEmpty {
                        subscriptionsSection
                            .id(StoreSection.subscriptions)
                    }

                    // Non-Consumables (Items)
                    if !storeManager.nonConsumableProducts.isEmpty {
                        itemsSection
                            .id(StoreSection.items)
                    }

                    // Energy Packs
                    energyPacksSection
                        .id(StoreSection.energy)

                    // Aether Coin Top-up
                    coinTopUpSection
                        .id(StoreSection.coins)

                    // Resource Exchange
                    resourceExchangeSection
                        .id(StoreSection.exchange)
                }
                .padding()
                .padding(.bottom, 120)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if let section = initialSection {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Current Tier Badge

    private var currentTierBadge: some View {
        HStack {
            Image(systemName: tierIcon(for: storeManager.currentMembershipTier))
                .font(.title2)
                .foregroundColor(tierColor(for: storeManager.currentMembershipTier))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedString.storeCurrentPlan)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(storeManager.currentMembershipTier.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                if storeManager.currentMembershipTier != .free,
                   let text = storeManager.formattedExpirationDate {
                    Text(text)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // Aether Coins balance
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("\(storeManager.aetherCoins)")
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(8)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Subscriptions Section

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "crown.fill",
                title: LocalizedString.storeSubscriptions,
                color: .yellow
            )

            ForEach(storeManager.subscriptionProducts, id: \.id) { product in
                SubscriptionCard(
                    product: product,
                    isCurrentPlan: storeManager.isCurrentPlan(product),
                    onPurchase: { await purchaseProduct(product) }
                )
            }
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "archivebox.fill",
                title: LocalizedString.storeItems,
                color: ApocalypseTheme.info
            )

            ForEach(storeManager.nonConsumableProducts, id: \.id) { product in
                ProductRow(
                    product: product,
                    isPurchased: storeManager.hasUnlock(product.id),
                    onPurchase: { await purchaseProduct(product) }
                )
            }
        }
    }

    // MARK: - Energy Packs Section

    private var energyPacksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "bolt.fill",
                title: LocalizedString.storeEnergyPacks,
                color: .yellow
            )

            // If Archon, show unlimited badge
            if storeManager.isInfiniteEnergyEnabled {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedString.vaultAetherEnergy)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(LocalizedString.vaultUnlimited)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                    Spacer()
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            } else {
                // Current energy balance
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text(LocalizedString.vaultAetherEnergy)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    Text("\(storeManager.aetherEnergy)")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ForEach(storeManager.energyPackProducts, id: \.id) { product in
                    energyPackRow(product: product)
                }
            }
        }
    }

    private func energyPackRow(product: Product) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                Task { await purchaseProduct(product) }
            } label: {
                Text(product.displayPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 70)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Coin Top-up Section

    private var coinTopUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "bitcoinsign.circle.fill",
                title: LocalizedString.storeCoinTopup,
                color: ApocalypseTheme.primary
            )

            ForEach(storeManager.coinPackProducts, id: \.id) { product in
                ProductRow(
                    product: product,
                    isPurchased: false,
                    onPurchase: { await purchaseProduct(product) }
                )
            }
        }
    }

    // MARK: - Resource Exchange Section

    private var resourceExchangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: LocalizedString.storeResourceExchange,
                    color: ApocalypseTheme.success
                )
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("\(storeManager.aetherCoins)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            ForEach(resourceExchangeRates, id: \.resourceName) { rate in
                exchangeRow(rate: rate)
            }
        }
    }

    private func exchangeRow(rate: ResourceExchangeRate) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rate.resourceColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: rate.resourceIcon)
                    .font(.title3)
                    .foregroundColor(rate.resourceColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rate.resourceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("\(rate.coinCost)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("\(rate.resourceAmount)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                performExchange(rate: rate)
            } label: {
                Text(LocalizedString.storeExchangeButton)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(storeManager.aetherCoins >= rate.coinCost ? ApocalypseTheme.primary : Color.gray.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(storeManager.aetherCoins < rate.coinCost)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: LocalizedStringResource, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Exchange Handler

    private func performExchange(rate: ResourceExchangeRate) {
        guard storeManager.spendAetherCoins(rate.coinCost) else {
            showInsufficientCoinsAlert = true
            return
        }

        // Create collected items for the resource
        let definition = ItemDefinition(
            id: rate.resourceName.lowercased(),
            name: rate.resourceName,
            description: "Exchanged from Aether Coins",
            category: ItemCategory(rawValue: rate.category) ?? .material,
            icon: rate.resourceIcon,
            rarity: .common
        )

        var items: [CollectedItem] = []
        for _ in 0..<rate.resourceAmount {
            items.append(CollectedItem(
                definition: definition,
                quality: .good,
                foundDate: Date(),
                quantity: 1
            ))
        }

        Task {
            await InventoryManager.shared.addItems(items, sourceType: "exchange")
        }

        print("🔄 [Exchange] Traded \(rate.coinCost) AEC → \(rate.resourceAmount) \(rate.resourceName)")
    }

    // MARK: - Purchase Handler

    private func purchaseProduct(_ product: Product) async {
        do {
            if let _ = try await storeManager.purchase(product) {
                showPurchaseSuccessAlert = true
            }
        } catch {
            // Error is handled by storeManager.errorMessage
        }
    }

    // MARK: - Helpers

    private func tierIcon(for tier: MembershipTier) -> String {
        switch tier {
        case .free: return "person"
        case .scavenger: return "person.fill"
        case .pioneer: return "star.fill"
        case .archon: return "crown.fill"
        }
    }

    private func tierColor(for tier: MembershipTier) -> Color {
        switch tier {
        case .free: return ApocalypseTheme.textSecondary
        case .scavenger: return Color.brown
        case .pioneer: return Color.gray
        case .archon: return Color.yellow
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StoreView()
    }
}
