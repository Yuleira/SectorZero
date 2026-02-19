//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布交易挂单视图
//  用户可以选择要出的物品和想要的物品，发布交易请求
//

import SwiftUI
import Supabase

struct CreateTradeOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

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
                #if DEBUG
                // 调试工具：填充库存
                Section {
                    Button {
                        Task {
                            await fillInventoryForTesting()
                        }
                    } label: {
                        Label(String(localized: LocalizedString.tradeDebugFillInventory), systemImage: "bag.fill.badge.plus")
                            .foregroundColor(.orange)
                    }

                    Button {
                        Task {
                            await testDatabaseConnection()
                        }
                    } label: {
                        Label(String(localized: LocalizedString.tradeDebugTestDatabase), systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.purple)
                    }

                    // 显示当前使用的 URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: LocalizedString.tradeDebugCurrentConfig))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(AppConfig.Supabase.projectURL)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if !inventoryManager.items.isEmpty {
                        Text(String(format: String(localized: LocalizedString.tradeDebugInventoryCount), inventoryManager.items.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(LocalizedString.tradeDebugTools)
                        .foregroundColor(.orange)
                }
                #endif

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

            debugLog("✅ Trade offer created: \(offerId)")
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    #if DEBUG
    /// 调试方法：填充库存以便测试交易系统
    private func fillInventoryForTesting() async {
        print("🔧 [DEBUG] Filling inventory for trade testing...")
        await inventoryManager.addBuildingTestResources()
        print("✅ [DEBUG] Inventory filled: \(inventoryManager.items.count) items")
    }

    /// 调试方法：测试数据库连接和 RPC 函数
    private func testDatabaseConnection() async {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 [DEBUG] Database Connection Test")
        print(String(repeating: "=", count: 60))

        // 1. 测试 Supabase 配置
        print("\n1️⃣ Supabase Configuration:")
        let url = AppConfig.Supabase.projectURL
        let key = AppConfig.Supabase.publishableKey
        let keyPreview = String(key.prefix(20)) + "..."
        print("   URL: \(url)")
        print("   Key: \(keyPreview)")

        // 手动验证配置
        let isValid = url.hasPrefix("https://") && url.contains(".supabase.co") &&
                     !url.contains("YOUR_PROJECT_ID") &&
                     key.count > 100 && key.hasPrefix("eyJ")
        print("   Valid: \(isValid ? "✅ YES" : "❌ NO")")

        // 2. 测试认证状态
        print("\n2️⃣ Authentication Status:")
        let authManager = AuthManager.shared
        print("   Authenticated: \(authManager.isAuthenticated ? "✅ YES" : "❌ NO")")
        if let userId = authManager.currentUser?.id {
            print("   User ID: \(userId)")
        }

        // 3. 测试简单的数据库查询（trade_offers 表）
        print("\n3️⃣ Testing Database Table Access:")
        do {
            let supabase = SupabaseService.shared.client
            let response = try await supabase
                .from("trade_offers")
                .select()
                .limit(1)
                .execute()

            print("   ✅ trade_offers table accessible")
            print("   Response size: \(response.data.count) bytes")
        } catch let error as PostgrestError {
            print("   ❌ trade_offers table error:")
            print("      Code: \(error.code ?? "unknown")")
            print("      Message: \(error.message)")
            if error.message.contains("relation") && error.message.contains("does not exist") {
                print("      ⚠️ Table 'trade_offers' does not exist!")
                print("      👉 Run migration: 007_trade_system.sql")
            }
        } catch {
            print("   ❌ Unexpected error: \(error)")
        }

        // 4. 测试 RPC 函数存在性
        print("\n4️⃣ Testing RPC Function:")
        do {
            let supabase = SupabaseService.shared.client

            // 使用一个简单的查询函数
            let response = try await supabase.rpc(
                "get_my_trade_offers"
            ).execute()

            print("   ✅ get_my_trade_offers() function exists")
            print("   Response size: \(response.data.count) bytes")

            // 测试主要的创建函数（预期会失败，因为参数不对，但能验证函数存在）
            print("\n   Testing create_trade_offer() existence...")
            // 不实际调用，只测试函数签名
            print("   ℹ️ Function signature check skipped (would need valid params)")

        } catch let error as PostgrestError {
            print("   ❌ RPC function error:")
            print("      Code: \(error.code ?? "unknown")")
            print("      Message: \(error.message)")
            if error.message.contains("function") && error.message.contains("does not exist") {
                print("      ⚠️ RPC functions do not exist!")
                print("      👉 Run migrations:")
                print("         1. 007_trade_system.sql")
                print("         2. 008_inventory_helper_functions.sql")
            }
        } catch {
            print("   ❌ Unexpected error: \(error)")
        }

        print("\n" + String(repeating: "=", count: 60))
        print("✅ Database test complete. Check Xcode console for details.")
        print(String(repeating: "=", count: 60) + "\n")

        // 显示用户友好的成功消息
        showSuccess = true
    }
    #endif
}

#Preview {
    CreateTradeOfferView()
}
