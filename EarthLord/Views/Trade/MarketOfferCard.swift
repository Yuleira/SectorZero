//
//  MarketOfferCard.swift
//  EarthLord
//
//  交易市场挂单卡片组件
//  显示其他玩家的挂单信息
//

import SwiftUI

struct MarketOfferCard: View {
    let offer: TradeOffer

    @StateObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：发布者和时间
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    Text(offer.ownerUsername ?? LocalizedString.tradeUnknownUser)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text(remainingTimeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 他出的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeTheyProvide)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(offer.offeringItems)
            }

            // 他要的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeTheyWant)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(offer.requestingItems)
            }

            // 留言预览
            if let message = offer.message, !message.isEmpty {
                Divider()

                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            // 查看详情按钮
            HStack {
                Spacer()
                Text(LocalizedString.tradeViewDetails)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
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
    MarketOfferCard(
        offer: TradeOffer(
            id: "1",
            ownerId: "user1",
            ownerUsername: "Player1",
            offeringItems: [TradeItem(itemId: "wood", quantity: 30)],
            requestingItems: [TradeItem(itemId: "stone", quantity: 20)],
            status: .active,
            message: "Need stone for building!",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 24)),
            completedAt: nil,
            completedByUserId: nil,
            completedByUsername: nil
        )
    )
    .padding()
}
