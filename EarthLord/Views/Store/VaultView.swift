//
//  VaultView.swift
//  EarthLord
//
//  Vault tab — displays Aether Energy, Aether Coins,
//  and View Subscription entry point.
//

import SwiftUI

struct VaultView: View {

    @ObservedObject private var storeManager = StoreKitManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Aether Energy Card
                aetherEnergyCard

                // Aether Coins Card
                aetherCoinsCard

                // View Subscription → Store subscriptions section
                NavigationLink(destination: StoreView(initialSection: .subscriptions)) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(LocalizedString.profileViewSubscription)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await storeManager.loadEntitlementsFromSupabase()
        }
    }

    // MARK: - Aether Energy Card

    private var aetherEnergyCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedString.vaultAetherEnergy)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                if storeManager.isInfiniteEnergyEnabled {
                    Text(LocalizedString.vaultUnlimited)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Text("\(storeManager.aetherEnergy)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            Spacer()

            if !storeManager.isInfiniteEnergyEnabled {
                NavigationLink(destination: StoreView(initialSection: .energy)) {
                    Text(LocalizedString.vaultBuyMore)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Aether Coins Card

    private var aetherCoinsCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedString.vaultAetherCoins)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("\(storeManager.aetherCoins)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            NavigationLink(destination: StoreView(initialSection: .coins)) {
                Text(LocalizedString.vaultTopUp)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VaultView()
            .background(ApocalypseTheme.background)
    }
}
