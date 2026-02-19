//
//  RateTradeSheet.swift
//  EarthLord
//
//  评价交易弹窗
//  用户可以对已完成的交易进行星级评价和评语
//

import SwiftUI
internal import Auth

struct RateTradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trade: TradeHistory

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var authManager = AuthManager.shared

    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    private var partnerUsername: String {
        let isSeller = trade.sellerId == authManager.currentUser?.id.uuidString
        let username = isSeller ? trade.buyerUsername : trade.sellerUsername
        return username ?? String(localized: LocalizedString.tradeUnknownUser)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // 交易对象
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text(String(format: String(localized: LocalizedString.tradeWithUserFormat), partnerUsername))
                        .font(.headline)
                }

                // 评分选择
                VStack(spacing: 16) {
                    Text(LocalizedString.tradeRateThisTrade)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { index in
                            Button {
                                rating = index
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: index <= rating ? "star.fill" : "star")
                                        .font(.system(size: 40))
                                        .foregroundColor(index <= rating ? .yellow : .gray)

                                    Text("\(index)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // 评语输入（可选）
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString.tradeCommentOptional)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField(LocalizedString.tradeCommentPlaceholder, text: $comment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()

                // 提交按钮
                Button {
                    Task {
                        await submitRating()
                    }
                } label: {
                    if isSubmitting {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text(LocalizedString.tradeSubmitting)
                        }
                    } else {
                        Text(LocalizedString.tradeSubmitRating)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isSubmitting)
            }
            .padding()
            .navigationTitle(LocalizedString.tradeRateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedString.commonCancel) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizedString.commonError, isPresented: $showErrorAlert) {
                Button(LocalizedString.commonOk) {
                    showErrorAlert = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func submitRating() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await tradeManager.rateTrade(
                tradeHistoryId: trade.id,
                rating: rating,
                comment: comment.isEmpty ? nil : comment
            )

            dismiss()
        } catch {
            debugLog("❌ Failed to submit rating: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview {
    RateTradeSheet(
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
            sellerRating: nil,
            buyerRating: nil,
            sellerComment: nil,
            buyerComment: nil
        )
    )
}
