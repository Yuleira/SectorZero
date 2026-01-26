//
//  MyOfferCard.swift
//  EarthLord
//
//  我的挂单卡片组件
//  显示单个挂单的详细信息
//

import SwiftUI

struct MyOfferCard: View {
    let offer: TradeOffer
    let onCancel: () -> Void

    @StateObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：状态和时间
            HStack {
                statusBadge
                Spacer()
                timeInfo
            }

            Divider()

            // 我出的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeIProvide)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(offer.offeringItems)
            }

            // 我要的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeIWant)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(offer.requestingItems)
            }

            Divider()

            // 底部信息
            HStack {
                if let completedByUsername = offer.completedByUsername {
                    Text(String(format: String(localized: LocalizedString.tradeAcceptedByFormat), completedByUsername))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if offer.status == .active && !offer.isExpired {
                    Button(LocalizedString.tradeCancelOffer, role: .destructive) {
                        onCancel()
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch offer.status {
        case .active:
            return offer.isExpired ? .orange : .blue
        case .completed:
            return .green
        case .cancelled:
            return .gray
        case .expired:
            return .orange
        }
    }

    private var statusText: LocalizedStringResource {
        if offer.status == .active && offer.isExpired {
            return LocalizedString.tradeStatusExpired
        }
        return offer.status.localizedName
    }

    @ViewBuilder
    private var timeInfo: some View {
        if offer.status == .active && !offer.isExpired {
            Text(remainingTimeText)
                .font(.caption)
                .foregroundColor(.secondary)
        } else if offer.status == .completed, let completedAt = offer.completedAt {
            Text(completedAt)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var remainingTimeText: String {
        let now = Date()
        let expiresDate = offer.expiresDate
        let timeInterval = expiresDate.timeIntervalSince(now)

        if timeInterval <= 0 {
            return String(localized: LocalizedString.tradeExpired)
        }

        let hours = Int(timeInterval / 3600)
        if hours < 1 {
            let minutes = Int(timeInterval / 60)
            return String(format: String(localized: LocalizedString.tradeRemainingMinutesFormat), minutes)
        } else {
            return String(format: String(localized: LocalizedString.tradeRemainingHoursFormat), hours)
        }
    }

    private func itemsList(_ items: [TradeItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Image(systemName: inventoryManager.resourceIconName(for: item.itemId))
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text(inventoryManager.resourceDisplayName(for: item.itemId))
                        .font(.subheadline)

                    Text("×\(item.quantity)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    MyOfferCard(
        offer: TradeOffer(
            id: "1",
            ownerId: "user1",
            ownerUsername: "Player1",
            offeringItems: [TradeItem(itemId: "wood", quantity: 30)],
            requestingItems: [TradeItem(itemId: "stone", quantity: 20)],
            status: .active,
            message: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 24)),
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        ),
        onCancel: {}
    )
    .padding()
}
