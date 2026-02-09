//
//  ProductRow.swift
//  EarthLord
//
//  Generic product row for energy pack consumables
//

import SwiftUI
import StoreKit

struct ProductRow: View {
    let product: Product
    let isPurchased: Bool
    let onPurchase: () async -> Void

    @State private var isPurchasing = false
    @State private var showDetail = false

    // MARK: - Product Styling

    private var productIcon: String {
        "bag.fill"
    }

    private var productColor: Color {
        ApocalypseTheme.textSecondary
    }

    private var isConsumable: Bool {
        product.type == .consumable
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Tappable area for detail sheet
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(productColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: productIcon)
                        .font(.title2)
                        .foregroundColor(productColor)
                }

                // Product Info
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
            .onTapGesture { showDetail = true }

            Spacer()

            // Purchase Button or Purchased Badge
            if isPurchased && !isConsumable {
                purchasedBadge
            } else {
                purchaseButton
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .sheet(isPresented: $showDetail) {
            ProductDetailSheet(
                product: product,
                isPurchased: isPurchased && !isConsumable,
                isCurrentPlan: false,
                onPurchase: onPurchase
            )
        }
    }

    // MARK: - Purchased Badge

    private var purchasedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(ApocalypseTheme.success)
            Text(LocalizedString.storePurchased)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.success.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard !isPurchasing else { return }
            isPurchasing = true
            Task {
                await onPurchase()
                isPurchasing = false
            }
        } label: {
            HStack(spacing: 4) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .frame(minWidth: 70)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(productColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isPurchasing)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        Text("Product Rows Preview")
            .foregroundColor(.white)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
