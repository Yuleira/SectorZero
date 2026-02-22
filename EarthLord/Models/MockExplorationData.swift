#if DEBUG
import Foundation

struct MockExplorationData {
    
    // 模拟定义
    static let sampleItemDef = ItemDefinition(
        id: "water_bottle",
        name: "纯净水",
        description: "一瓶还算干净的水。",
        category: .water,
        icon: "drop.fill"
    )
    
    // 模拟物品
    static let sampleItem = CollectedItem(
        definition: sampleItemDef,
        quality: .good,
        foundDate: Date(),
        quantity: 1
    )
    
    // 模拟统计
    static let sampleExplorationStats = ExplorationStats(
        totalDistance: 1250.5,
        duration: 3600,
        pointsVerified: 5,
        distanceRank: "A"
    )
    
    // 模拟结果
    static let sampleExplorationResult = ExplorationResult(
        isSuccess: true,
        message: "探索成功！",
        itemsCollected: [sampleItem, sampleItem],
        experienceGained: 150,
        distanceWalked: 1250.5,
        stats: sampleExplorationStats,
        startTime: Date().addingTimeInterval(-3600), // 1小时前
        endTime: Date() // 现在
    )
    
    // 补上 View 需要的辅助方法
    static func getItemDefinition(id: String) -> ItemDefinition {
        return sampleItemDef
    }
}
#endif
