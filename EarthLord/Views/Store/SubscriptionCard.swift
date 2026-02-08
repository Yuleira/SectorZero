//
//  SubscriptionCard.swift
//  EarthLord
//
//  Subscription tier display card for the store
//

import SwiftUI
import StoreKit

struct SubscriptionCard: View {
    let product: Product
    let isCurrentPlan: Bool
    let onPurchase: () async -> Void

    @State private var isPurchasing = false

    // MARK: - Tier Styling

    private var tierColor: Color {
        switch product.id {
        case StoreProductID.scavenger.rawValue:
            return Color.brown
        case StoreProductID.pioneer.rawValue:
            return Color.gray
        case StoreProductID.archon.rawValue:
            return Color.yellow
        default:
            return ApocalypseTheme.primary
        }
    }

    private var tierIcon: String {
        switch product.id {
        case StoreProductID.scavenger.rawValue:
            return "person.fill"
        case StoreProductID.pioneer.rawValue:
            return "star.fill"
        case StoreProductID.archon.rawValue:
            return "crown.fill"
        default:
            return "questionmark"
        }
    }

    private var isBestValue: Bool {
        product.id == StoreProductID.archon.rawValue
    }

    private var isPopular: Bool {
        product.id == StoreProductID.pioneer.rawValue
    }

    // MARK: - Body

    var body: some View {
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
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 4) {
                        Text(product.displayPrice)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(tierColor)
                        Text(LocalizedString.storePerMonth)
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

            // Description
            Text(product.description)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(3)

            // Benefits list based on tier
            benefitsList

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
            switch product.id {
            case StoreProductID.scavenger.rawValue:
                benefitRow(LocalizedString.storeBenefitTerritories5)
                benefitRow(LocalizedString.storeBenefitDailyEnergy3)
                benefitRow(LocalizedString.storeBenefitDailyCoins5)
                benefitRow(LocalizedString.storeBenefitStorage150)

            case StoreProductID.pioneer.rawValue:
                benefitRow(LocalizedString.storeBenefitTerritories10)
                benefitRow(LocalizedString.storeBenefitDailyEnergy5)
                benefitRow(LocalizedString.storeBenefitDailyCoins15)
                benefitRow(LocalizedString.storeBenefitStorage300)

            case StoreProductID.archon.rawValue:
                benefitRow(LocalizedString.storeBenefitTerritories25)
                benefitRow(LocalizedString.storeBenefitUnlimitedScans)
                benefitRow(LocalizedString.storeBenefitDailyCoins30)
                benefitRow(LocalizedString.storeBenefitStorage600)

            default:
                EmptyView()
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
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard !isCurrentPlan && !isPurchasing else { return }
            isPurchasing = true
            Task {
                await onPurchase()
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
            .foregroundColor(.white)
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
