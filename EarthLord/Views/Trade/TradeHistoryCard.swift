//
//  TradeHistoryCard.swift
//  EarthLord
//
//  交易历史卡片组件
//  显示已完成的交易记录和评价信息
//

import SwiftUI

struct TradeHistoryCard: View {
    let trade: TradeHistory
    let currentUserId: String
    let onRate: () -> Void

    @StateObject private var inventoryManager = InventoryManager.shared

    private var isSeller: Bool {
        trade.sellerId == currentUserId
    }

    private var partnerUsername: String {
        isSeller ? (trade.buyerUsername ?? LocalizedString.tradeUnknownUser) : (trade.sellerUsername ?? LocalizedString.tradeUnknownUser)
    }

    private var myRating: Int? {
        isSeller ? trade.sellerRating : trade.buyerRating
    }

    private var myComment: String? {
        isSeller ? trade.sellerComment : trade.buyerComment
    }

    private var partnerRating: Int? {
        isSeller ? trade.buyerRating : trade.sellerRating
    }

    private var partnerComment: String? {
        isSeller ? trade.buyerComment : trade.sellerComment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：交易对象和时间
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    Text(String(format: String(localized: LocalizedString.tradeWithUserFormat), partnerUsername))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text(trade.formattedCompletedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 你给出的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeYouGave)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(isSeller ? trade.itemsExchanged.offered : trade.itemsExchanged.requested)
            }

            // 你获得的物品
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedString.tradeYouReceived)
                    .font(.caption)
                    .foregroundColor(.secondary)

                itemsList(isSeller ? trade.itemsExchanged.requested : trade.itemsExchanged.offered)
            }

            Divider()

            // 评价信息
            VStack(alignment: .leading, spacing: 8) {
                // 我的评价
                if let rating = myRating {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedString.tradeYourRating)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            starsView(rating: rating)
                        }
                        if let comment = myComment, !comment.isEmpty {
                            Text("\"\(comment)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                } else {
                    Button {
                        onRate()
                    } label: {
                        HStack {
                            Image(systemName: "star")
                            Text(LocalizedString.tradeRateNow)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }

                // 对方的评价
                if let rating = partnerRating {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedString.tradePartnerRating)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            starsView(rating: rating)
                        }
                        if let comment = partnerComment, !comment.isEmpty {
                            Text("\"\(comment)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                } else {
                    Text(LocalizedString.tradeNotRatedYet)
                        .font(.caption)
                        .foregroundColor(.secondary)
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

    private func starsView(rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(index <= rating ? .yellow : .gray)
            }
        }
    }
}

#Preview {
    TradeHistoryCard(
        trade: TradeHistory(
            id: "1",
            offerId: "offer1",
            sellerId: "user1",
            sellerUsername: "Seller",
            buyerId: "user2",
            buyerUsername: "Buyer",
            itemsExchanged: ItemsExchanged(
                offered: [TradeItem(itemId: "wood", quantity: 30)],
                requested: [TradeItem(itemId: "stone", quantity: 20)]
            ),
            completedAt: ISO8601DateFormatter().string(from: Date()),
            sellerRating: 5,
            buyerRating: 4,
            sellerComment: "Great trade!",
            buyerComment: "Fast and reliable"
        ),
        currentUserId: "user1",
        onRate: {}
    )
    .padding()
}
