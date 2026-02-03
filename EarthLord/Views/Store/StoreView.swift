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
    @ObservedObject private var storeManager = StoreKitManager.shared
    @State private var showRestoreAlert = false
    @State private var showPurchaseSuccessAlert = false
    @State private var showFetchErrorAlert = false
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
                ToolbarItem(placement: .navigationBarLeading) {
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
                    .accessibilityLabel(LocalizedString.storeRefresh)
                }
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
                await storeManager.loadEntitlementsFromSupabase()
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

    // MARK: - Products List

    private var productsList: some View {
        ScrollView(.vertical, showsIndicators: true) {
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
            .padding(.bottom, 120) // Extra bottom padding so last items scroll above tab bar
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
