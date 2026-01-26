//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史视图
//  显示已完成的交易记录，可以进行评价
//

import SwiftUI

struct TradeHistoryView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var tradeToRate: TradeHistory?
    @State private var showRatingSheet = false

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                ProgressView()
            } else if tradeManager.tradeHistory.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            if let trade = tradeToRate {
                RateTradeSheet(trade: trade)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(LocalizedString.tradeHistoryEmptyTitle)
                .font(.headline)

            Text(LocalizedString.tradeHistoryEmptySubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { trade in
                    TradeHistoryCard(
                        trade: trade,
                        currentUserId: authManager.currentUser?.id ?? "",
                        onRate: {
                            tradeToRate = trade
                            showRatingSheet = true
                        }
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await tradeManager.loadTradeHistory()
        }
    }
}

#Preview {
    TradeHistoryView()
}
