//
//  ProductDetailSheet.swift
//  EarthLord
//
//  Detail sheet for store products — shows game-context description,
//  benefits list, and current-vs-after comparison table.
//

import SwiftUI
import StoreKit

// MARK: - Product Detail Info Model

struct ProductDetailInfo {
    let icon: String
    let accentColor: Color
    /// Text color for buttons with accentColor background (black for yellow, white otherwise)
    let buttonTextColor: Color
    let headline: LocalizedStringResource
    let description: LocalizedStringResource
    let benefits: [BenefitItem]
    let comparison: [ComparisonRow]

    struct BenefitItem {
        let icon: String
        let text: LocalizedStringResource
    }

    struct ComparisonRow {
        let label: LocalizedStringResource
        let currentValue: String
        let newValue: String
        let improved: Bool
    }

    // MARK: - Factory

    static func info(for product: Product, storeManager: StoreKitManager) -> ProductDetailInfo? {
        guard let productID = StoreProductID(rawValue: product.id) else { return nil }

        let currentTier = storeManager.currentMembershipTier

        switch productID {

        // MARK: Subscriptions — Scavenger

        case .scavengerMonthly, .scavengerYearly:
            return ProductDetailInfo(
                icon: "person.fill",
                accentColor: .brown,
                buttonTextColor: .white,
                headline: LocalizedString.detailSalvagerHeadline,
                description: LocalizedString.detailSalvagerDesc,
                benefits: [
                    BenefitItem(icon: "map.fill", text: LocalizedString.storeBenefitTerritories5),
                    BenefitItem(icon: "bolt.fill", text: LocalizedString.storeBenefitDailyScans5),
                    BenefitItem(icon: "archivebox.fill", text: LocalizedString.storeBenefitStorage150),
                ],
                comparison: [
                    ComparisonRow(label: LocalizedString.detailLabelTerritories,
                                  currentValue: "\(currentTier.maxTerritories)",
                                  newValue: "5",
                                  improved: currentTier.maxTerritories < 5),
                    ComparisonRow(label: LocalizedString.detailLabelDailyEnergy,
                                  currentValue: "\(storeManager.dailyEnergyAmount)",
                                  newValue: "5",
                                  improved: storeManager.dailyEnergyAmount < 5),
                    ComparisonRow(label: LocalizedString.detailLabelStorage,
                                  currentValue: "\(storeManager.currentStorageLimit)",
                                  newValue: "150",
                                  improved: storeManager.currentStorageLimit < 150),
                ]
            )

        // MARK: Subscriptions — Pioneer

        case .pioneerMonthly, .pioneerYearly:
            return ProductDetailInfo(
                icon: "star.fill",
                accentColor: ApocalypseTheme.info,
                buttonTextColor: .white,
                headline: LocalizedString.detailPioneerHeadline,
                description: LocalizedString.detailPioneerDesc,
                benefits: [
                    BenefitItem(icon: "map.fill", text: LocalizedString.storeBenefitTerritories10),
                    BenefitItem(icon: "bolt.fill", text: LocalizedString.storeBenefitDailyScans10),
                    BenefitItem(icon: "archivebox.fill", text: LocalizedString.storeBenefitStorage300),
                ],
                comparison: [
                    ComparisonRow(label: LocalizedString.detailLabelTerritories,
                                  currentValue: "\(currentTier.maxTerritories)",
                                  newValue: "10",
                                  improved: currentTier.maxTerritories < 10),
                    ComparisonRow(label: LocalizedString.detailLabelDailyEnergy,
                                  currentValue: "\(storeManager.dailyEnergyAmount)",
                                  newValue: "10",
                                  improved: storeManager.dailyEnergyAmount < 10),
                    ComparisonRow(label: LocalizedString.detailLabelStorage,
                                  currentValue: "\(storeManager.currentStorageLimit)",
                                  newValue: "300",
                                  improved: storeManager.currentStorageLimit < 300),
                ]
            )

        // MARK: Subscriptions — Archon

        case .archonMonthly, .archonYearly:
            let currentScans = storeManager.isInfiniteEnergyEnabled
                ? String(localized: LocalizedString.detailUnlimited)
                : "\(storeManager.dailyEnergyAmount)"
            return ProductDetailInfo(
                icon: "crown.fill",
                accentColor: .yellow,
                buttonTextColor: .black,
                headline: LocalizedString.detailArchonHeadline,
                description: LocalizedString.detailArchonDesc,
                benefits: [
                    BenefitItem(icon: "map.fill", text: LocalizedString.storeBenefitTerritories25),
                    BenefitItem(icon: "bolt.fill", text: LocalizedString.storeBenefitUnlimitedScans),
                    BenefitItem(icon: "archivebox.fill", text: LocalizedString.storeBenefitStorage600),
                ],
                comparison: [
                    ComparisonRow(label: LocalizedString.detailLabelTerritories,
                                  currentValue: "\(currentTier.maxTerritories)",
                                  newValue: "25",
                                  improved: currentTier.maxTerritories < 25),
                    ComparisonRow(label: LocalizedString.detailLabelAIScans,
                                  currentValue: currentScans,
                                  newValue: String(localized: LocalizedString.detailUnlimited),
                                  improved: !storeManager.isInfiniteEnergyEnabled),
                    ComparisonRow(label: LocalizedString.detailLabelStorage,
                                  currentValue: "\(storeManager.currentStorageLimit)",
                                  newValue: "600",
                                  improved: storeManager.currentStorageLimit < 600),
                ]
            )

        // MARK: Energy Packs

        case .energy5, .energy20, .energy50:
            let amount = productID.energyAmount ?? 0
            let currentEnergy = storeManager.aetherEnergy
            return ProductDetailInfo(
                icon: "bolt.fill",
                accentColor: .yellow,
                buttonTextColor: .black,
                headline: LocalizedString.detailEnergyHeadline,
                description: LocalizedString.detailEnergyDesc,
                benefits: [
                    BenefitItem(icon: "bolt.fill", text: LocalizedString.detailEnergyCostPerScan),
                    BenefitItem(icon: "mappin.and.ellipse", text: LocalizedString.detailEnergyScanPois),
                    BenefitItem(icon: "plus.circle.fill", text: LocalizedString.detailEnergyScansCount),
                ],
                comparison: [
                    ComparisonRow(label: LocalizedString.detailLabelEnergy,
                                  currentValue: "\(currentEnergy)",
                                  newValue: "\(currentEnergy + amount)",
                                  improved: true),
                ]
            )
        }
    }
}

// MARK: - Product Detail Sheet View

struct ProductDetailSheet: View {
    let product: Product
    let isPurchased: Bool
    let isCurrentPlan: Bool
    let onPurchase: () async -> Void

    @ObservedObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    private var info: ProductDetailInfo? {
        ProductDetailInfo.info(for: product, storeManager: storeManager)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                if let info = info {
                    VStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 24) {
                                heroSection(info: info)
                                headlineSection(info: info)
                                descriptionSection(info: info)
                                benefitsSection(info: info)
                                if !info.comparison.isEmpty {
                                    comparisonSection(info: info)
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                        }

                        // Sticky purchase button
                        purchaseButton(info: info)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
        }
    }

    // MARK: - Hero Section

    private func heroSection(info: ProductDetailInfo) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(info.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: info.icon)
                    .font(.system(size: 36))
                    .foregroundColor(info.accentColor)
            }

            Text(product.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(product.displayPrice)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(info.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Headline

    private func headlineSection(info: ProductDetailInfo) -> some View {
        Text(info.headline)
            .font(.headline)
            .foregroundColor(info.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Description

    private func descriptionSection(info: ProductDetailInfo) -> some View {
        Text(info.description)
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Benefits List

    private func benefitsSection(info: ProductDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(info.benefits.enumerated()), id: \.offset) { _, benefit in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.info)
                    Text(benefit.text)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Comparison Table

    private func comparisonSection(info: ProductDetailInfo) -> some View {
        VStack(spacing: 12) {
            // Header row
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(LocalizedString.detailNow)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 70)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(LocalizedString.detailAfter)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(width: 70)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // Data rows
            ForEach(Array(info.comparison.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.currentValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 70)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(row.newValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(row.improved ? ApocalypseTheme.info : ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 70)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Purchase Button

    private func purchaseButton(info: ProductDetailInfo) -> some View {
        let isDisabled = isPurchased || isCurrentPlan || isPurchasing

        return VStack {
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            Button {
                guard !isDisabled else { return }
                isPurchasing = true
                Task {
                    await onPurchase()
                    isPurchasing = false
                    dismiss()
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else if isCurrentPlan {
                        Text(LocalizedString.storeCurrentPlan)
                            .fontWeight(.semibold)
                    } else if isPurchased {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(LocalizedString.storePurchased)
                        }
                        .fontWeight(.semibold)
                    } else {
                        Text("\(String(localized: LocalizedString.storeSubscribe))  \(product.displayPrice)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDisabled ? Color.gray.opacity(0.5) : info.accentColor)
                .foregroundColor(isDisabled ? .white : info.buttonTextColor)
                .cornerRadius(12)
            }
            .disabled(isDisabled)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    Text("Product Detail Sheet Preview")
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
}
