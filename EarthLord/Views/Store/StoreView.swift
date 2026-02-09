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
    case energy

    var id: String { rawValue }
}

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
    @State private var selectedEnergyProduct: Product? = nil

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

                    // Energy Packs
                    energyPacksSection
                        .id(StoreSection.energy)
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

            // Energy balance
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                if storeManager.isInfiniteEnergyEnabled {
                    Image(systemName: "infinity")
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Text("\(storeManager.aetherEnergy)")
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
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

            // Show one SubscriptionCard per tier (monthly products drive it)
            ForEach(storeManager.monthlySubscriptionProducts, id: \.id) { monthlyProduct in
                let yearlyProduct = yearlyProductForMonthly(monthlyProduct)
                SubscriptionCard(
                    monthlyProduct: monthlyProduct,
                    yearlyProduct: yearlyProduct,
                    isCurrentPlan: storeManager.isCurrentPlan(monthlyProduct),
                    onPurchase: { product in await purchaseProduct(product) }
                )
            }
        }
    }

    /// Find the yearly counterpart for a monthly subscription product
    private func yearlyProductForMonthly(_ monthlyProduct: Product) -> Product? {
        guard let storeID = StoreProductID(rawValue: monthlyProduct.id),
              let yearlyID = storeID.yearlyCounterpart else { return nil }
        return storeManager.product(for: yearlyID)
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
        .sheet(item: $selectedEnergyProduct) { product in
            ProductDetailSheet(
                product: product,
                isPurchased: false,
                isCurrentPlan: false,
                onPurchase: { await purchaseProduct(product) }
            )
        }
    }

    private func energyPackRow(product: Product) -> some View {
        HStack(spacing: 16) {
            // Tappable area for detail sheet
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
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedEnergyProduct = product }

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
