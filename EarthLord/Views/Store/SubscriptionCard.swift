//
//  SubscriptionCard.swift
//  EarthLord
//
//  Subscription tier display card with monthly/yearly toggle
//

import SwiftUI
import StoreKit

struct SubscriptionCard: View {
    let monthlyProduct: Product
    let yearlyProduct: Product?
    let isCurrentPlan: Bool
    let onPurchase: (Product) async -> Void

    @State private var isYearly = false
    @State private var isPurchasing = false
    @State private var showDetail = false

    private var activeProduct: Product {
        (isYearly ? yearlyProduct : nil) ?? monthlyProduct
    }

    // MARK: - Tier Styling

    private var tierColor: Color {
        guard let storeID = StoreProductID(rawValue: monthlyProduct.id) else {
            return ApocalypseTheme.primary
        }
        switch storeID.tier {
        case .salvager: return Color.brown
        case .pioneer: return ApocalypseTheme.info
        case .archon: return Color.yellow
        default: return ApocalypseTheme.primary
        }
    }

    private var tierButtonTextColor: Color {
        guard let storeID = StoreProductID(rawValue: monthlyProduct.id),
              storeID.tier == .archon else { return .white }
        return .black
    }

    private var tierIcon: String {
        guard let storeID = StoreProductID(rawValue: monthlyProduct.id) else {
            return "questionmark"
        }
        switch storeID.tier {
        case .salvager: return "person.fill"
        case .pioneer: return "star.fill"
        case .archon: return "crown.fill"
        default: return "questionmark"
        }
    }

    private var isBestValue: Bool {
        StoreProductID(rawValue: monthlyProduct.id)?.tier == .archon
    }

    private var isPopular: Bool {
        StoreProductID(rawValue: monthlyProduct.id)?.tier == .pioneer
    }

    /// Yearly savings percentage badge text
    private var savingsBadge: String? {
        guard let yearly = yearlyProduct else { return nil }
        let monthlyAnnual = monthlyProduct.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let savings = ((monthlyAnnual - yearly.price) / monthlyAnnual * 100)
            .formatted(.number.precision(.fractionLength(0)))
        return "Save \(savings)%"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tappable area for detail sheet
            VStack(alignment: .leading, spacing: 16) {
                // Badges
                if isBestValue || isPopular {
                    HStack {
                        if isBestValue {
                            badgeView(text: LocalizedString.storeBestValue, color: ApocalypseTheme.warning)
                        }
                        if isPopular {
                            badgeView(text: LocalizedString.storePopular, color: ApocalypseTheme.info)
                        }
                        Spacer()
                    }
                }

                // Header: Icon + Name + Price
                HStack {
                    Image(systemName: tierIcon)
                        .font(.title2)
                        .foregroundColor(tierColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(monthlyProduct.displayName)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        HStack(spacing: 4) {
                            Text(activeProduct.displayPrice)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(tierColor)
                            Text(isYearly ? LocalizedString.storePerYear : LocalizedString.storePerMonth)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    if isCurrentPlan {
                        Text(LocalizedString.storeCurrentPlan)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ApocalypseTheme.success.opacity(0.2))
                            .foregroundColor(ApocalypseTheme.success)
                            .cornerRadius(8)
                    }
                }

                // Monthly / Yearly Toggle
                if yearlyProduct != nil {
                    periodToggle
                }

                // Description
                Text(activeProduct.description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(3)

                // Benefits list based on tier
                benefitsList
            }
            .contentShape(Rectangle())
            .onTapGesture { showDetail = true }

            // Purchase Button
            purchaseButton
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCurrentPlan ? ApocalypseTheme.success :
                        (isBestValue ? tierColor.opacity(0.5) : Color.clear),
                    lineWidth: 2
                )
        )
        .sheet(isPresented: $showDetail) {
            ProductDetailSheet(
                product: activeProduct,
                isPurchased: false,
                isCurrentPlan: isCurrentPlan,
                onPurchase: { await onPurchase(activeProduct) }
            )
        }
    }

    // MARK: - Period Toggle

    private var periodToggle: some View {
        HStack(spacing: 0) {
            toggleButton(label: LocalizedString.monthlyPlan, isSelected: !isYearly) {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = false }
            }
            toggleButton(label: LocalizedString.yearlyPlan, isSelected: isYearly, badge: savingsBadge) {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = true }
            }
        }
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
    }

    private func toggleButton(label: LocalizedStringResource, isSelected: Bool, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(ApocalypseTheme.success.opacity(0.2))
                        .foregroundColor(ApocalypseTheme.success)
                        .cornerRadius(3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? tierColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? tierColor : ApocalypseTheme.textSecondary)
            .cornerRadius(8)
        }
    }

    // MARK: - Badge View

    private func badgeView(text: LocalizedStringResource, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            guard let storeID = StoreProductID(rawValue: monthlyProduct.id),
                  let tier = storeID.tier else {
                return AnyView(EmptyView())
            }

            switch tier {
            case .salvager:
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    benefitRow(LocalizedString.storeBenefitTerritories5)
                    benefitRow(LocalizedString.storeBenefitDailyScans5)
                    benefitRow(LocalizedString.storeBenefitStorage150)
                })

            case .pioneer:
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    benefitRow(LocalizedString.storeBenefitTerritories10)
                    benefitRow(LocalizedString.storeBenefitDailyScans10)
                    benefitRow(LocalizedString.storeBenefitStorage300)
                })

            case .archon:
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    benefitRow(LocalizedString.storeBenefitTerritories25)
                    benefitRow(LocalizedString.storeBenefitUnlimitedScans)
                    benefitRow(LocalizedString.storeBenefitStorage600)
                })

            default:
                return AnyView(EmptyView())
            }
        }
    }

    private func benefitRow(_ text: LocalizedStringResource) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(tierColor)
            Text(text)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard !isCurrentPlan && !isPurchasing else { return }
            isPurchasing = true
            Task {
                await onPurchase(activeProduct)
                isPurchasing = false
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(isCurrentPlan ? LocalizedString.storeCurrentPlan : LocalizedString.storeSubscribe)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isCurrentPlan ? Color.gray.opacity(0.5) : tierColor)
            .foregroundColor(isCurrentPlan ? .white : tierButtonTextColor)
            .cornerRadius(10)
        }
        .disabled(isCurrentPlan || isPurchasing)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Mock preview - in real usage, products come from StoreKitManager
        Text("Subscription Cards Preview")
            .foregroundColor(.white)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
