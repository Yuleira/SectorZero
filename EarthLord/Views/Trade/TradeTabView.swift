//
//  TradeTabView.swift
//  EarthLord
//
//  交易系统主视图
//  包含三个标签页：我的挂单、交易市场、交易历史
//

import SwiftUI

struct TradeTabView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var selectedTab: TradeTab = .myOffers

    enum TradeTab {
        case myOffers
        case market
        case history
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部分段控件
            Picker("", selection: $selectedTab) {
                Text(LocalizedString.tradeMyOffers)
                    .tag(TradeTab.myOffers)
                Text(LocalizedString.tradeMarketTitle)
                    .tag(TradeTab.market)
                Text(LocalizedString.tradeHistory)
                    .tag(TradeTab.history)
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            TabView(selection: $selectedTab) {
                MyOffersView()
                    .tag(TradeTab.myOffers)

                TradeMarketView()
                    .tag(TradeTab.market)

                TradeHistoryView()
                    .tag(TradeTab.history)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(LocalizedString.tradeSystemTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 初始加载数据
            await loadInitialData()
        }
    }

    private func loadInitialData() async {
        async let myOffers: Void = tradeManager.loadMyOffers()
        async let availableOffers: Void = tradeManager.loadAvailableOffers()
        async let history: Void = tradeManager.loadTradeHistory()

        _ = await (myOffers, availableOffers, history)
    }
}

#Preview {
    NavigationStack {
        TradeTabView()
    }
}
