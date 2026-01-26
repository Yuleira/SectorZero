//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布交易挂单视图
//  用户可以选择要出的物品和想要的物品，发布交易请求
//

import SwiftUI

struct CreateTradeOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared

    // 表单状态
    @State private var offeringItems: [TradeItem] = []
    @State private var requestingItems: [TradeItem] = []
    @State private var validityHours: Int = 24
    @State private var message: String = ""

    // UI 状态
    @State private var showOfferingPicker = false
    @State private var showRequestingPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    private let validityOptions = [1, 6, 12, 24, 48, 72]

    var body: some View {
        NavigationView {
            Form {
                // 我要出的物品
                Section {
                    if offeringItems.isEmpty {
                        Button {
                            showOfferingPicker = true
                        } label: {
                            Label(LocalizedString.tradeAddItem, systemImage: "plus.circle")
                        }
                    } else {
                        ForEach(offeringItems) { item in
                            TradeItemRow(
                                item: item,
                                onDelete: {
                                    offeringItems.removeAll { $0.itemId == item.itemId }
                                }
                            )
                        }

                        Button {
                            showOfferingPicker = true
                        } label: {
                            Label(LocalizedString.tradeAddItem, systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text(LocalizedString.tradeOfferingItems)
                }

                // 我想要的物品
                Section {
                    if requestingItems.isEmpty {
                        Button {
                            showRequestingPicker = true
                        } label: {
                            Label(LocalizedString.tradeAddItem, systemImage: "plus.circle")
                        }
                    } else {
                        ForEach(requestingItems) { item in
                            TradeItemRow(
                                item: item,
                                onDelete: {
                                    requestingItems.removeAll { $0.itemId == item.itemId }
                                }
                            )
                        }

                        Button {
                            showRequestingPicker = true
                        } label: {
                            Label(LocalizedString.tradeAddItem, systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text(LocalizedString.tradeRequestingItems)
                }

                // 有效期
                Section {
                    Picker(LocalizedString.tradeValidityPeriod, selection: $validityHours) {
                        ForEach(validityOptions, id: \.self) { hours in
                            Text(validityHoursText(hours))
                                .tag(hours)
                        }
                    }
                } header: {
                    Text(LocalizedString.tradeValidityPeriod)
                }

                // 留言（可选）
                Section {
                    TextField(LocalizedString.tradeMessagePlaceholder, text: $message, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(LocalizedString.tradeMessageOptional)
                }

                // 发布按钮
                Section {
                    Button {
                        Task {
                            await submitOffer()
                        }
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text(LocalizedString.tradePublishing)
                            }
                        } else {
                            Text(LocalizedString.tradePublishOffer)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle(LocalizedString.tradeCreateOffer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedString.commonCancel) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showOfferingPicker) {
                ItemPickerSheet(
                    mode: .fromInventory,
                    selectedItems: $offeringItems
                )
            }
            .sheet(isPresented: $showRequestingPicker) {
                ItemPickerSheet(
                    mode: .anyItem,
                    selectedItems: $requestingItems
                )
            }
            .alert(LocalizedString.commonError, isPresented: $showError) {
                Button(LocalizedString.commonOk) {
                    showError = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert(LocalizedString.tradeSuccessTitle, isPresented: $showSuccess) {
                Button(LocalizedString.commonOk) {
                    dismiss()
                }
            } message: {
                Text(LocalizedString.tradePublished)
            }
        }
    }

    private var canSubmit: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty
    }

    private func validityHoursText(_ hours: Int) -> String {
        if hours < 24 {
            return String(format: String(localized: LocalizedString.tradeValidityHoursFormat), hours)
        } else {
            let days = hours / 24
            return String(format: String(localized: LocalizedString.tradeValidityDaysFormat), days)
        }
    }

    private func submitOffer() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let offerId = try await tradeManager.createTradeOffer(
                offeringItems: offeringItems,
                requestingItems: requestingItems,
                validityHours: validityHours,
                message: message.isEmpty ? nil : message
            )

            print("✅ Trade offer created: \(offerId)")
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    CreateTradeOfferView()
}
