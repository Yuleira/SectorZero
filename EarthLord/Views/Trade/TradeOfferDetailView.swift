//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  交易挂单详情视图
//  显示挂单的完整信息，并允许用户接受交易
//

import SwiftUI

struct TradeOfferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let offer: TradeOffer

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var showConfirmDialog = false
    @State private var isAccepting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var receivedItems: [TradeItem] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 发布者信息
                    publisherInfo

                    Divider()

                    // 他提供的物品
                    itemsSection(
                        title: LocalizedString.tradeTheyProvide,
                        items: offer.offeringItems
                    )

                    // 他想要的物品
                    itemsSection(
                        title: LocalizedString.tradeTheyWant,
                        items: offer.requestingItems
                    )

                    // 留言
                    if let message = offer.message, !message.isEmpty {
                        messageSection(message)
                    }

                    Divider()

                    // 库存检查
                    inventoryCheckSection

                    // 接受交易按钮
                    acceptButton
                }
                .padding()
            }
            .navigationTitle(LocalizedString.tradeOfferDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedString.commonCancel) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                LocalizedString.tradeConfirmTitle,
                isPresented: $showConfirmDialog
            ) {
                Button(LocalizedString.tradeConfirmAccept, role: .destructive) {
                    Task {
                        await acceptTrade()
                    }
                }
                Button(LocalizedString.commonCancel, role: .cancel) {}
            } message: {
                Text(confirmDialogMessage)
            }
            .alert(LocalizedString.tradeSuccessTitle, isPresented: $showSuccessAlert) {
                Button(LocalizedString.commonOk) {
                    dismiss()
                }
            } message: {
                Text(successMessage)
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

    private var publisherInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(offer.ownerUsername ?? String(localized: LocalizedString.tradeUnknownUser))
                    .font(.headline)
            }

            HStack(spacing: 4) {
                Text(LocalizedString.tradePublishedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(offer.formattedCreatedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(remainingTimeText)
                    .font(.caption)
                    .foregroundColor(offer.isExpired ? .red : .secondary)
            }
        }
    }

    private func itemsSection(title: LocalizedStringResource, items: [TradeItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(items) { item in
                    itemCard(item)
                }
            }
        }
    }

    private func itemCard(_ item: TradeItem) -> some View {
        VStack(spacing: 8) {
            Image(systemName: inventoryManager.resourceIconName(for: item.itemId))
                .font(.largeTitle)
                .foregroundColor(.blue)

            Text(inventoryManager.resourceDisplayName(for: item.itemId))
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Text("×\(item.quantity)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.secondary)
                Text(LocalizedString.tradeMessage)
                    .font(.headline)
            }

            Text("\"\(message)\"")
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var inventoryCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedString.tradeYourInventory)
                .font(.headline)

            ForEach(offer.requestingItems) { item in
                inventoryCheckRow(item)
            }
        }
    }

    private func inventoryCheckRow(_ item: TradeItem) -> some View {
        let available = inventoryManager.getResourceQuantity(for: item.itemId)
        let isEnough = available >= item.quantity

        return HStack {
            Image(systemName: inventoryManager.resourceIconName(for: item.itemId))
                .foregroundColor(.blue)

            Text(inventoryManager.resourceDisplayName(for: item.itemId))
                .font(.subheadline)

            Spacer()

            Text("×\(available)")
                .font(.subheadline)
                .foregroundColor(isEnough ? .primary : .red)

            Image(systemName: isEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnough ? .green : .red)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var acceptButton: some View {
        Button {
            showConfirmDialog = true
        } label: {
            if isAccepting {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text(LocalizedString.tradeAccepting)
                }
            } else {
                Text(LocalizedString.tradeAccept)
            }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(canAccept ? Color.green : Color.gray)
        .cornerRadius(12)
        .disabled(!canAccept || isAccepting)
    }

    private var canAccept: Bool {
        !offer.isExpired && offer.requestingItems.allSatisfy { item in
            inventoryManager.getResourceQuantity(for: item.itemId) >= item.quantity
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

    private var confirmDialogMessage: String {
        var message = String(localized: LocalizedString.tradeConfirmMessage) + "\n\n"

        message += String(localized: LocalizedString.tradeYouWillPay) + "\n"
        for item in offer.requestingItems {
            message += "· \(inventoryManager.resourceDisplayName(for: item.itemId)) ×\(item.quantity)\n"
        }

        message += "\n" + String(localized: LocalizedString.tradeYouWillReceive) + "\n"
        for item in offer.offeringItems {
            message += "· \(inventoryManager.resourceDisplayName(for: item.itemId)) ×\(item.quantity)\n"
        }

        return message
    }

    private var successMessage: String {
        var message = String(localized: LocalizedString.tradeSuccessMessage) + "\n\n"

        for item in receivedItems {
            message += "· \(inventoryManager.resourceDisplayName(for: item.itemId)) ×\(item.quantity)\n"
        }

        return message
    }

    private func acceptTrade() async {
        isAccepting = true
        defer { isAccepting = false }

        do {
            let result = try await tradeManager.acceptTradeOffer(offerId: offer.id)
            receivedItems = result.receivedItems
            showSuccessAlert = true
        } catch {
            debugLog("❌ Failed to accept trade: \(error)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview {
    TradeOfferDetailView(
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
}
