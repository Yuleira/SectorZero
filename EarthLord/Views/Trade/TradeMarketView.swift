//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场视图
//  显示其他玩家的挂单，可以接受交易
//

import SwiftUI

struct TradeMarketView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var selectedOffer: TradeOffer?
    @State private var showOfferDetail = false

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                ProgressView()
            } else if tradeManager.availableOffers.isEmpty {
                emptyStateView
            } else {
                offersList
            }
        }
        .sheet(isPresented: $showOfferDetail) {
            if let offer = selectedOffer {
                TradeOfferDetailView(offer: offer)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(LocalizedString.tradeMarketEmptyTitle)
                .font(.headline)

            Text(LocalizedString.tradeMarketEmptySubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.availableOffers) { offer in
                    MarketOfferCard(offer: offer)
                        .onTapGesture {
                            selectedOffer = offer
                            showOfferDetail = true
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
    }
}

#Preview {
    TradeMarketView()
}
