//
//  TradeItemRow.swift
//  EarthLord
//
//  交易物品行组件
//  在发布挂单表单中显示单个物品
//

import SwiftUI

struct TradeItemRow: View {
    let item: TradeItem
    let onDelete: () -> Void

    @StateObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            Image(systemName: inventoryManager.resourceIconName(for: item.itemId))
                .foregroundColor(.blue)
                .frame(width: 30)
                .font(.title3)

            // 物品名称和数量
            VStack(alignment: .leading, spacing: 2) {
                Text(inventoryManager.resourceDisplayName(for: item.itemId))
                    .font(.body)

                Text("×\(item.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 删除按钮
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        TradeItemRow(
            item: TradeItem(itemId: "wood", quantity: 30),
            onDelete: {}
        )
        TradeItemRow(
            item: TradeItem(itemId: "stone", quantity: 20),
            onDelete: {}
        )
    }
}
