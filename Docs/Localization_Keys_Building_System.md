# Building System Localization Keys

This document tracks all localization keys added during the Building System refactoring.

## Category Names

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `category_survival` | Survival | 生存 | Building category |
| `category_storage` | Storage | 存储 | Building category |
| `category_production` | Production | 生产 | Building category |
| `category_energy` | Energy | 能源 | Building category |

## Building Status

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `status_constructing` | Constructing | 建造中 | Building status |
| `status_active` | Active | 已激活 | Building status |
| `building_completing` | Completing... | 即将完成... | Countdown near zero |

## Error Messages

| Key | English | 中文 | Context |
|-----|---------|------|---------|
| `error_insufficient_resources` | Insufficient resources: %@ | 资源不足：%@ | Missing materials |
| `error_max_buildings_reached` | Maximum %d buildings reached | 已达上限 %d 个建筑 | Territory limit |
| `error_invalid_status` | Invalid building status | 建筑状态无效 | State machine error |
| `error_template_not_found` | Building template not found | 建筑模板未找到 | Template lookup fail |
| `error_not_authenticated` | Please log in first | 请先登录 | User not authenticated |

## Implementation Notes

### Current Status
- All keys use `NSLocalizedString()` with comment parameter
- Keys follow snake_case convention for consistency
- Format specifiers: `%@` (string), `%d` (integer)

### Next Steps
1. Add these keys to `Localizable.xcstrings`
2. Provide English and Chinese translations
3. Test all UI components with both languages

### Example Usage in Code

```swift
// Category display name
Text(category.displayName) // Uses NSLocalizedString("category_survival", ...)

// Error message
let error = BuildingError.insufficientResources(missing: ["wood": 10])
Text(error.localizedDescription) // Formatted with resource list
```

### Fallback Behavior
If a key is not found in Localizable.xcstrings:
- The key itself will be displayed (e.g., "category_survival")
- This makes missing translations obvious during testing
