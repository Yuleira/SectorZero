# Phase 3 Localization Keys

Additional localization keys required for Building Location Picker & Placement views.

## Location Picker

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `common_cancel` | Cancel | 取消 | Cancel button |
| `common_ok` | OK | 确定 | OK button |
| `building_tap_to_place` | Tap to place building | 点击放置建筑 | Map instruction |
| `building_confirm_location` | Confirm Location | 确认位置 | Confirm button |
| `building_selected_location` | Selected Location | 已选位置 | Map marker title |
| `building_location_invalid` | Invalid Location | 无效位置 | Alert title |
| `building_location_outside_territory` | Location must be inside your territory | 位置必须在领地内 | Validation error |

## Building Placement

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `building_place_title` | Place Building | 放置建筑 | Navigation title |
| `building_tier %d` | Tier %d | 等级 %d | Building tier |
| `building_build_time` | Build Time | 建造时间 | Label |
| `building_max_per_territory` | Max per Territory | 领地上限 | Label |
| `building_required_resources` | Required Resources | 所需资源 | Section title |
| `building_resources_sufficient` | Sufficient | 资源充足 | Status badge |
| `building_resources_insufficient` | Insufficient | 资源不足 | Status badge |
| `building_select_location` | Select Location | 选择位置 | Section title |
| `building_location_selected` | Selected | 已选择 | Status badge |
| `building_location_coordinates` | Location Coordinates | 位置坐标 | Label |
| `building_tap_to_select_location` | Tap to select location on map | 点击选择地图位置 | Button prompt |
| `building_start_construction` | Start Construction | 开始建造 | Main action button |
| `building_construction_success` | Construction Started | 建造已开始 | Success alert title |
| `building_construction_started %@` | %@ construction has begun | %@ 建造已开始 | Success message |
| `building_construction_failed` | Construction Failed | 建造失败 | Error alert title |
| `building_error_no_location` | Please select a location on the map | 请在地图上选择位置 | Error message |

## Implementation Notes

### Format Specifiers
- `%d` - Integer (tier, count)
- `%@` - String (building name, error details)
- `%.6f` - Floating point with 6 decimals (coordinates)

### Usage Examples

```swift
// Simple localization
Text(String(localized: "building_tap_to_place"))

// With integer format
Text(String(localized: "building_tier \(template.tier)"))

// With string interpolation
Text(String(localized: "building_construction_started \(template.name)"))

// Coordinate display (not localized)
Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
```

### Coordinate Display
Coordinates are displayed as raw numbers (not localized) for technical accuracy:
```swift
String(format: "%.6f, %.6f", location.latitude, location.longitude)
```

### GCJ-02 Warnings in Code
All location-related components include warnings:
```swift
/// ⚠️ 重要：选中的坐标为 GCJ-02，直接保存到数据库
/// ⚠️ coordinate 来自地图点击，已经是 GCJ-02
```
