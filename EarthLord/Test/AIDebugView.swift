//
//  AIDebugView.swift
//  EarthLord
//
//  AI 物品生成调试界面
//  用于测试 AI 生成功能，无需实际探索
//

import SwiftUI
import CoreLocation

struct AIDebugView: View {
    @State private var isGenerating = false
    @State private var testResults: String = "点击按钮开始测试..."
    @State private var generatedItems: [AIGeneratedItem] = []
    @State private var usedFallback = false
    @State private var generationTime: TimeInterval = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题
                headerSection
                
                // 测试按钮区域
                testButtonsSection
                
                // 结果显示
                resultsSection
                
                // 生成的物品列表
                if !generatedItems.isEmpty {
                    itemsListSection
                }
            }
            .padding()
        }
        .navigationTitle("AI 生成器调试")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 标题区域
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("AI 物品生成测试")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("测试 Edge Function 和降级方案")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    // MARK: - 测试按钮区域
    
    private var testButtonsSection: some View {
        VStack(spacing: 16) {
            // 加油站测试按钮
            testButton(
                title: "🏪 测试 AI 生成 (加油站)",
                subtitle: "危险等级 3，生成 3 件物品",
                color: .blue
            ) {
                await testGasStation()
            }
            
            // 医院测试按钮
            testButton(
                title: "🏥 测试 AI 生成 (医院)",
                subtitle: "危险等级 4，生成 4 件物品",
                color: .red
            ) {
                await testHospital()
            }
            
            // 超市测试按钮
            testButton(
                title: "🛒 测试 AI 生成 (超市)",
                subtitle: "危险等级 2，生成 3 件物品",
                color: .green
            ) {
                await testSupermarket()
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // 降级方案测试按钮
            testButton(
                title: "⚙️ 测试降级方案",
                subtitle: "使用本地生成（不调用 AI）",
                color: .orange
            ) {
                await testFallback()
            }
        }
    }
    
    // MARK: - 结果显示区域
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("测试结果")
                    .font(.headline)
                Spacer()
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            // 状态标签
            if !generatedItems.isEmpty {
                HStack {
                    Label(
                        usedFallback ? "降级方案" : "AI 生成",
                        systemImage: usedFallback ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(usedFallback ? .orange : .green)
                    
                    Spacer()
                    
                    Text(String(format: "%.2fs", generationTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // 日志文本框
            ScrollView {
                Text(testResults)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 200)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 物品列表区域
    
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成的物品")
                .font(.headline)
            
            ForEach(Array(generatedItems.enumerated()), id: \.offset) { index, item in
                itemCard(item: item, index: index + 1)
            }
        }
    }
    
    // MARK: - 通用测试按钮
    
    private func testButton(
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color)
            .cornerRadius(12)
        }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.6 : 1.0)
    }
    
    // MARK: - 物品卡片
    
    private func itemCard(item: AIGeneratedItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rarityColor(item.rarity))
                    .cornerRadius(6)
                
                Text(item.name)
                    .font(.headline)
                
                Spacer()
                
                Text(item.rarity)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(rarityColor(item.rarity))
            }
            
            HStack {
                Image(systemName: categoryIcon(item.category))
                    .foregroundColor(.secondary)
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(item.story)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 测试方法
    
    /// 测试加油站
    private func testGasStation() async {
        await testAIGeneration(
            name: "废弃加油站",
            type: .gasStation,
            dangerLevel: 3,
            itemCount: 3
        )
    }
    
    /// 测试医院
    private func testHospital() async {
        await testAIGeneration(
            name: "中心医院",
            type: .hospital,
            dangerLevel: 4,
            itemCount: 4
        )
    }
    
    /// 测试超市
    private func testSupermarket() async {
        await testAIGeneration(
            name: "华联超市",
            type: .supermarket,
            dangerLevel: 2,
            itemCount: 3
        )
    }
    
    /// 通用 AI 测试方法
    private func testAIGeneration(
        name: String,
        type: POIType,
        dangerLevel: Int,
        itemCount: Int
    ) async {
        isGenerating = true
        generatedItems.removeAll()
        usedFallback = false
        testResults = "[\(currentTime)] 🚀 开始测试 AI 生成...\n"
        testResults += "[\(currentTime)] POI: \(name) (\(type.rawValue))\n"
        testResults += "[\(currentTime)] 危险等级: \(dangerLevel), 物品数量: \(itemCount)\n"
        testResults += "[\(currentTime)] 调用 Edge Function...\n\n"
        
        // 创建模拟 POI
        let mockPOI = NearbyPOI(
            id: "debug-\(UUID().uuidString)",
            name: name,
            type: type,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        
        let startTime = Date()
        
        // 调用 AI 生成
        let items = await AIItemGenerator.shared.generateItems(for: mockPOI, count: itemCount)
        
        generationTime = Date().timeIntervalSince(startTime)
        
        if let items = items {
            // AI 生成成功
            generatedItems = items
            usedFallback = false
            
            testResults += "[\(currentTime)] ✅ AI 生成成功！\n"
            testResults += "[\(currentTime)] 耗时: \(String(format: "%.2f", generationTime))秒\n"
            testResults += "[\(currentTime)] 生成了 \(items.count) 个物品:\n\n"
            
            for (index, item) in items.enumerated() {
                testResults += "[\(currentTime)] #\(index + 1) \(item.name)\n"
                testResults += "  分类: \(item.category) → \(item.itemCategory)\n"
                testResults += "  稀有度: \(item.rarity) → \(item.itemRarity.rawValue)\n"
                testResults += "  故事: \(item.story)\n\n"
            }
        } else {
            // AI 失败，使用降级方案
            testResults += "[\(currentTime)] ⚠️ AI 生成失败，使用降级方案...\n\n"
            
            let fallbackItems = AIItemGenerator.shared.generateFallbackItems(for: mockPOI, count: itemCount)
            generatedItems = fallbackItems
            usedFallback = true
            
            testResults += "[\(currentTime)] ✅ 降级方案生成成功！\n"
            testResults += "[\(currentTime)] 耗时: \(String(format: "%.2f", generationTime))秒\n"
            testResults += "[\(currentTime)] 生成了 \(fallbackItems.count) 个物品:\n\n"
            
            for (index, item) in fallbackItems.enumerated() {
                testResults += "[\(currentTime)] #\(index + 1) \(item.name)\n"
                testResults += "  分类: \(item.category) → \(item.itemCategory)\n"
                testResults += "  稀有度: \(item.rarity) → \(item.itemRarity.rawValue)\n"
                testResults += "  故事: \(item.story)\n\n"
            }
        }
        
        isGenerating = false
    }
    
    /// 测试降级方案
    private func testFallback() async {
        isGenerating = true
        generatedItems.removeAll()
        usedFallback = true
        testResults = "[\(currentTime)] ⚙️ 测试降级方案（不调用 AI）...\n\n"
        
        // 创建模拟 POI
        let mockPOI = NearbyPOI(
            id: "debug-fallback",
            name: "测试药店",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        
        let startTime = Date()
        
        // 直接调用降级方案
        let items = AIItemGenerator.shared.generateFallbackItems(for: mockPOI, count: 3)
        
        generationTime = Date().timeIntervalSince(startTime)
        generatedItems = items
        
        testResults += "[\(currentTime)] ✅ 降级方案生成完成！\n"
        testResults += "[\(currentTime)] 耗时: \(String(format: "%.2f", generationTime))秒\n"
        testResults += "[\(currentTime)] 生成了 \(items.count) 个物品:\n\n"
        
        for (index, item) in items.enumerated() {
            testResults += "[\(currentTime)] #\(index + 1) \(item.name)\n"
            testResults += "  分类: \(item.category) → \(item.itemCategory)\n"
            testResults += "  稀有度: \(item.rarity) → \(item.itemRarity.rawValue)\n"
            testResults += "  故事: \(item.story)\n\n"
        }
        
        testResults += "[\(currentTime)] 📝 注意：降级方案使用本地预设物品池，不需要网络连接\n"
        
        isGenerating = false
    }
    
    // MARK: - 辅助方法
    
    /// 当前时间格式化
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    /// 稀有度颜色
    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }
    
    /// 分类图标
    private func categoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "medical", "医疗": return "cross.case.fill"
        case "food", "食物": return "fork.knife"
        case "tool", "工具": return "wrench.and.screwdriver.fill"
        case "weapon", "武器": return "shield.fill"
        case "material", "材料": return "gearshape.fill"
        case "water", "水": return "drop.fill"
        default: return "shippingbox.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AIDebugView()
    }
}
