//
//  StoreView.swift
//  EarthLord
//
//  Main store UI for In-App Purchases
//  Displays subscriptions, items, and premium currency
//

import SwiftUI
import StoreKit

struct StoreView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showRestoreAlert = false
    @State private var showPurchaseSuccessAlert = false
    @State private var restoreMessage: String = ""

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .task {
                await storeManager.fetchProducts()
                await storeManager.loadEntitlementsFromSupabase()
            }
            .alert(Text(LocalizedString.storePurchaseSuccessful), isPresented: $showPurchaseSuccessAlert) {
                Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
            }
            .alert(Text(LocalizedString.storeRestorePurchases), isPresented: $showRestoreAlert) {
                Button(String(localized: LocalizedString.commonOk), role: .cancel) {}
            } message: {
                Text(restoreMessage)
            }
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

            Button {
                Task {
                    await storeManager.fetchProducts()
                }
            } label: {
                Text(LocalizedString.refresh)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - Products List

    private var productsList: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Current Tier Badge
                currentTierBadge

                // Subscriptions Section
                if !storeManager.subscriptionProducts.isEmpty {
                    subscriptionsSection
                }

                // Non-Consumables Section
                if !storeManager.nonConsumableProducts.isEmpty {
                    itemsSection
                }

                // Consumables Section
                if !storeManager.consumableProducts.isEmpty {
                    currencySection
                }
            }
            .padding()
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
            }

            Spacer()

            // Shards balance
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("\(storeManager.shardsBalance)")
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
            Text(LocalizedString.storeSubscriptions)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

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
            Text(LocalizedString.storeItems)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(storeManager.nonConsumableProducts, id: \.id) { product in
                ProductRow(
                    product: product,
                    isPurchased: storeManager.hasUnlock(product.id),
                    onPurchase: { await purchaseProduct(product) }
                )
            }
        }
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedString.storePremiumCurrency)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            ForEach(storeManager.consumableProducts, id: \.id) { product in
                ProductRow(
                    product: product,
                    isPurchased: false,
                    onPurchase: { await purchaseProduct(product) }
                )
            }
        }
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
    StoreView()
}
