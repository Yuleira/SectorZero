# Phase 4 Localization Keys

Additional localization keys required for Building Lifecycle & Integration features.

## Territory Renaming

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `territory_rename_success` | Territory renamed successfully | 领地重命名成功 | Success message |
| `territory_rename_failed` | Failed to rename territory: %@ | 领地重命名失败: %@ | Error message |

## Building Status Colors (Section 6.2)

### Status Colors Reference

| Status | Color | Hex | Usage |
|--------|-------|-----|-------|
| `constructing` | Cyan | #00BFFF | Progress ring, status badge |
| `active` | Green | #00FF00 | Active building indicator |

### Implementation

```swift
// BuildingModels.swift
enum BuildingStatus: String, Codable {
    case constructing
    case active
    
    var accentColor: Color {
        switch self {
        case .constructing:
            return .cyan // Construction in progress
        case .active:
            return .green // Building is operational
        }
    }
}
```

## Building List Display

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `building_level_format` | Lv.%d | 等级 %d | Building level display |
| `building_completing` | Completing... | 即将完成... | When time remaining ≤ 0 |

## Developer Tools (DEBUG Only)

These are only visible in DEBUG builds and do not require localization.

### Debug Log Messages (English Only)

```swift
print("📦 [DEBUG] 添加测试资源: \(resourceId) x\(quantity)")
print("📦 [DEBUG] ✅ 测试资源添加完成")
print("📦 [DEBUG] 开始清空背包...")
print("📦 [DEBUG] ✅ 背包已清空")
print("📦 [DEBUG] 添加建筑测试资源包...")
print("📦 [DEBUG] ✅ 建筑测试资源包添加完成")
```

## Progress Timer Logs (Developer Only)

These are internal logs and do not require localization:

```swift
print("🏗️ [建筑] 启动进度定时器")
print("🏗️ [建筑] 停止进度定时器")
print("🏗️ [建筑] 定时器检测到建筑完成")
```

## Map Building Annotations

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `status_constructing` | Constructing | 建造中 | Building annotation subtitle |
| `status_active` | Active | 运行中 | Building annotation subtitle |

### Annotation Display

```swift
// BuildingAnnotation subtitle
var subtitle: String? {
    if building.status == .constructing {
        return String(localized: "status_constructing")
    } else {
        return String(format: String(localized: "building_level_format"), building.level)
    }
}
```

## NotificationCenter Events (No Localization Needed)

```swift
extension Notification.Name {
    static let territoryUpdated = Notification.Name("territoryUpdated")
}
```

## Implementation Notes

### 1. Progress Timer

**Frequency**: Updates every 1 second
**Triggers**: `objectWillChange.send()` to refresh UI
**Auto-completion**: Checks `buildCompletedAt` and calls `completeConstruction()`

### 2. Building Annotation Colors

Match the BuildingCategory colors:

| Category | Color |
|----------|-------|
| Survival | Orange |
| Storage | Brown |
| Production | Indigo |
| Energy | Yellow |

### 3. Status Opacity

| Status | Opacity |
|--------|---------|
| Constructing | 60% (0.6) |
| Active | 100% (1.0) |

### 4. Developer Tools Usage

```swift
#if DEBUG
// Add test resources
await InventoryManager.shared.addTestResource(resourceId: "wood", quantity: 500)

// Add full building test pack
await InventoryManager.shared.addBuildingTestResources()

// Clear all items
await InventoryManager.shared.clearAllItems()
#endif
```

## Complete Localization Key Summary

### All Keys Added in Phase 4

1. `territory_rename_success`
2. `territory_rename_failed`
3. `building_level_format`
4. `building_completing`
5. `status_constructing` (if not already added)
6. `status_active` (if not already added)

### Existing Keys Reused

- `common_ok`
- `common_cancel`
- `common_loading`

## Color Standards (Section 6.2 Compliance)

All status colors match the Day 29 specification:

```swift
// ✅ Compliant
case .constructing: return .cyan
case .active: return .green

// Building categories
case .survival: return .orange
case .storage: return .brown
case .production: return .indigo
case .energy: return .yellow
```

## Testing Checklist

- [ ] Progress timer updates every second
- [ ] Buildings auto-complete when time expires
- [ ] Territory rename triggers list refresh
- [ ] Building annotations render on main map
- [ ] GCJ-02 coordinates used directly (no conversion)
- [ ] Developer tools accessible in DEBUG
- [ ] All status colors match specification
