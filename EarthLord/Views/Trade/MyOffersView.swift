//
//  MyOffersView.swift
//  EarthLord
//
//  我的挂单列表视图
//  显示用户发布的所有交易挂单
//

import SwiftUI

struct MyOffersView: View {
    @StateObject private var tradeManager = TradeManager.shared
    @State private var showCreateOffer = false
    @State private var offerToCancel: TradeOffer?
    @State private var showCancelConfirm = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                ProgressView()
            } else if tradeManager.myOffers.isEmpty {
                emptyStateView
            } else {
                offersList
            }
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView()
        }
        .confirmationDialog(
            LocalizedString.tradeCancelOfferTitle,
            isPresented: $showCancelConfirm,
            presenting: offerToCancel
        ) { offer in
            Button(LocalizedString.commonConfirm, role: .destructive) {
                Task {
                    await cancelOffer(offer)
                }
            }
            Button(LocalizedString.commonCancel, role: .cancel) {}
        } message: { offer in
            Text(LocalizedString.tradeCancelOfferMessage)
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(LocalizedString.tradeNoOffersTitle)
                .font(.headline)

            Text(LocalizedString.tradeNoOffersSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateOffer = true
            } label: {
                Label(LocalizedString.tradeCreateOffer, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    private var offersList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 发布新挂单按钮
                Button {
                    showCreateOffer = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(LocalizedString.tradeCreateOffer)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding()

                Divider()

                // 挂单列表
                LazyVStack(spacing: 12) {
                    ForEach(tradeManager.myOffers) { offer in
                        MyOfferCard(
                            offer: offer,
                            onCancel: {
                                offerToCancel = offer
                                showCancelConfirm = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
    }

    private func cancelOffer(_ offer: TradeOffer) async {
        do {
            try await tradeManager.cancelTradeOffer(offerId: offer.id)
            // 成功提示会在 TradeManager 中处理
        } catch {
            debugLog("❌ Failed to cancel offer: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview {
    MyOffersView()
}
