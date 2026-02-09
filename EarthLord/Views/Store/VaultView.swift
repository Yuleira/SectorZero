//
//  VaultView.swift
//  EarthLord
//
//  Vault tab — displays Aether Energy, Storage,
//  and View Subscription entry point.
//

import SwiftUI

struct VaultView: View {

    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Aether Energy Card
                aetherEnergyCard

                // Storage Card
                storageCard

                // View Subscription → Store subscriptions section
                NavigationLink(destination: StoreView(initialSection: .subscriptions)) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text(LocalizedString.profileViewSubscription)
                    }
                    .font(.headline)
                    .foregroundColor(.black)
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

    // MARK: - Storage Card

    private var storageCard: some View {
        let usage = inventoryManager.currentUsage
        let limit = storeManager.currentStorageLimit
        let progress = limit > 0 ? Double(usage) / Double(limit) : 0
        let isFull = usage >= limit

        return VStack(spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((isFull ? ApocalypseTheme.danger : ApocalypseTheme.info).opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "archivebox.fill")
                        .font(.title2)
                        .foregroundColor(isFull ? ApocalypseTheme.danger : ApocalypseTheme.info)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.vaultStorage)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("\(usage) / \(limit)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isFull ? ApocalypseTheme.danger : ApocalypseTheme.textPrimary)
                }

                Spacer()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isFull ? ApocalypseTheme.danger : ApocalypseTheme.info)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            if isFull {
                Text(LocalizedString.vaultStorageFull)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
