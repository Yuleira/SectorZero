//
//  ItemPickerSheet.swift
//  EarthLord
//
//  物品选择器弹窗
//  用于在发布挂单时选择物品和数量
//

import SwiftUI

struct ItemPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum PickerMode {
        case fromInventory  // 从库存中选择（有数量限制）
        case anyItem        // 选择任意物品（无限制）
    }

    let mode: PickerMode
    @Binding var selectedItems: [TradeItem]

    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var searchText = ""
    @State private var selectedItemId: String?
    @State private var quantity: Int = 1
    @State private var showQuantityPicker = false

    private var availableItems: [(String, Int)] {
        let items: [(String, Int)]

        switch mode {
        case .fromInventory:
            // 从库存中获取物品，确保ID规范化（小写）以支持UUID和字符串ID
            items = inventoryManager.items.map { item in
                // 使用小写ID以确保与building资源ID（如"wood"）兼容
                let normalizedId = item.definition.id.lowercased()
                return (normalizedId, item.quantity)
            }
        case .anyItem:
            // 获取所有可能的物品定义（这里使用建筑资源作为示例）
            items = [
                ("wood", 999),
                ("stone", 999),
                ("metal", 999),
                ("fabric", 999),
                ("glass", 999),
                ("scrap_metal", 999),
                ("circuit", 999),
                ("concrete", 999)
            ]
        }

        // 过滤掉已选择的物品（规范化比较）
        return items.filter { itemId, _ in
            let normalizedId = itemId.lowercased()
            return !selectedItems.contains { $0.itemId.lowercased() == normalizedId }
        }
    }

    private var filteredItems: [(String, Int)] {
        if searchText.isEmpty {
            return availableItems
        } else {
            return availableItems.filter { itemId, _ in
                inventoryManager.resourceDisplayName(for: itemId)
                    .lowercased()
                    .contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                searchBar

                Divider()

                // 物品网格
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemsGrid
                }
            }
            .navigationTitle(LocalizedString.tradeSelectItem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedString.commonCancel) {
                        dismiss()
                    }
                }
            }
            .task {
                // 确保库存已加载
                if inventoryManager.items.isEmpty {
                    await inventoryManager.loadItems()
                }
            }
            .sheet(isPresented: $showQuantityPicker) {
                if let itemId = selectedItemId,
                   let maxQuantity = availableItems.first(where: { $0.0.lowercased() == itemId.lowercased() })?.1 {
                    QuantityPickerSheet(
                        itemId: itemId,
                        maxQuantity: maxQuantity,
                        mode: mode,
                        onConfirm: { selectedQuantity in
                            addItem(itemId: itemId, quantity: selectedQuantity)
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(LocalizedString.tradeSearchItems, text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text(LocalizedString.tradeNoItemsAvailable)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredItems, id: \.0) { itemId, quantity in
                    itemCard(itemId: itemId, quantity: quantity)
                }
            }
            .padding()
        }
    }

    private func itemCard(itemId: String, quantity: Int) -> some View {
        Button {
            selectedItemId = itemId
            self.quantity = 1
            showQuantityPicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: inventoryManager.resourceIconName(for: itemId))
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Text(inventoryManager.resourceDisplayName(for: itemId))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if mode == .fromInventory {
                    Text("×\(quantity)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func addItem(itemId: String, quantity: Int) {
        let newItem = TradeItem(itemId: itemId, quantity: quantity)
        selectedItems.append(newItem)
    }
}

// 数量选择器弹窗
struct QuantityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let itemId: String
    let maxQuantity: Int
    let mode: ItemPickerSheet.PickerMode
    let onConfirm: (Int) -> Void

    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var quantity: Int = 1

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // 物品图标和名称
                VStack(spacing: 12) {
                    Image(systemName: inventoryManager.resourceIconName(for: itemId))
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text(inventoryManager.resourceDisplayName(for: itemId))
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                // 库存信息
                if mode == .fromInventory {
                    Text(String(format: String(localized: LocalizedString.tradeInStockFormat), maxQuantity))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 数量选择器
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        Button {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(quantity > 1 ? .blue : .gray)
                        }
                        .disabled(quantity <= 1)

                        Text("\(quantity)")
                            .font(.system(size: 40, weight: .bold))
                            .frame(minWidth: 100)

                        Button {
                            let limit = mode == .fromInventory ? maxQuantity : 999
                            if quantity < limit {
                                quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(quantity < (mode == .fromInventory ? maxQuantity : 999) ? .blue : .gray)
                        }
                        .disabled(quantity >= (mode == .fromInventory ? maxQuantity : 999))
                    }

                    // 快速选择按钮（仅在库存模式）
                    if mode == .fromInventory && maxQuantity > 10 {
                        HStack(spacing: 12) {
                            quickSelectButton(value: maxQuantity / 4, labelText: "1/4")
                            quickSelectButton(value: maxQuantity / 2, labelText: "1/2")
                            quickSelectButton(value: maxQuantity, labelText: String(localized: LocalizedString.tradeSelectAll))
                        }
                    }
                }

                Spacer()

                // 确认按钮
                Button {
                    onConfirm(quantity)
                } label: {
                    Text(LocalizedString.tradeConfirmAdd)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle(LocalizedString.tradeSelectQuantity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedString.commonCancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func quickSelectButton(value: Int, labelText: String) -> some View {
        Button {
            quantity = value
        } label: {
            Text(labelText)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
    }
}

#Preview {
    ItemPickerSheet(
        mode: .fromInventory,
        selectedItems: .constant([])
    )
}
