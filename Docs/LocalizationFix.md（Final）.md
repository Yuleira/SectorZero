# LocalizationFix.md（Final Submission · Minimal）

> **Authoritative UI copy for EarthLord**  
> This document defines the final, human-readable UI text for the app.  
> Only keys listed here may be modified in `Localizable.xcstrings`.

---

## 🏗️ Building System (Day 29)

| Key                             | Chinese (Simplified) | English                | Notes                    |
| ------------------------------- | -------------------- | ---------------------- | ------------------------ |
| building_start_construction     | 开始建造                 | Start Construction     | Primary action button    |
| building_confirm_construction   | 确认建造                 | Confirm Construction   | Confirmation action      |
| building_resources_insufficient | 资源不足                 | Insufficient Resources | Disabled / warning state |
| building_resources_sufficient   | 资源充足                 | Enough Resources       | Availability indicator   |
| building_select_location        | 选择位置                 | Select Location        | Placement step           |
| building_location_selected      | 已选位置                 | Location Selected      | Placement feedback       |
| building_construction_success   | 建造已开始                | Construction Started   | Success toast / banner   |
| building_max_reached            | 已达建造上限               | Build Limit Reached    | Max-per-territory limit  |
| building_tier_format            | 等级 %lld              | Tier %lld              | Format string            |
| building_level_format           | 等级 %lld              | Level %lld             | Format string            |

---

## 🧱 Building Categories

| Key                 | Chinese (Simplified) | English    | Notes             |
| ------------------- | -------------------- | ---------- | ----------------- |
| category_survival   | 生存设施                 | Survival   | Building category |
| category_storage    | 储存设施                 | Storage    | Building category |
| category_production | 生产设施                 | Production | Building category |
| category_energy     | 能源设施                 | Energy     | Building category |

---

## 🗺️ Territory & Map

| Key                     | Chinese (Simplified) | English               | Notes         |
| ----------------------- | -------------------- | --------------------- | ------------- |
| territory_buildings     | 领地建筑                 | Territory Buildings   | Section title |
| territory_points_format | 领地积分 %lld            | Territory Points %lld | Format string |
| territory_no_buildings  | 暂无建筑                 | No Buildings Yet      | Empty state   |

---

## 🎒 Inventory & Resources

| Key                 | Chinese (Simplified) | English      | Notes         |
| ------------------- | -------------------- | ------------ | ------------- |
| inventory_resources | 资源                   | Resources    | Section title |
| inventory_empty     | 暂无资源                 | No Resources | Empty state   |
| resource_wood       | 木材                   | Wood         | Resource name |
| resource_stone      | 石头                   | Stone        | Resource name |
| resource_metal      | 金属                   | Metal        | Resource name |
| resource_concrete   | 混凝土                  | Concrete     | Resource name |
| resource_glass      | 玻璃                   | Glass        | Resource name |

---

## 🧭 Navigation & Common UI

| Key            | Chinese (Simplified) | English | Notes          |
| -------------- | -------------------- | ------- | -------------- |
| common_confirm | 确认                   | Confirm | Generic action |
| common_cancel  | 取消                   | Cancel  | Generic action |
| common_close   | 关闭                   | Close   | Generic action |
| common_back    | 返回                   | Back    | Navigation     |

---

## 👤 Profile & Settings (Minimal)

| Key                            | Chinese (Simplified) | English                                                        | Notes               |
| ------------------------------ | -------------------- | -------------------------------------------------------------- | ------------------- |
| profile_delete_confirm_title   | 删除确认                 | Delete Confirmation                                            | Dialog title        |
| profile_delete_confirm_message | 确定要删除吗？此操作无法撤销。      | Are you sure you want to delete? This action cannot be undone. | Confirmation prompt |

---

## ⚠️ Rules (Do Not Violate)

- **Do NOT rename keys listed above**

- **Do NOT copy key names into values**

- **Do NOT introduce new keys without updating this file**

- **Format placeholders (`%lld`, `%@`) belong ONLY in values**

- Debug-only strings are intentionally excluded

---

### ✅ Status

- Scope: **Assignment / Demo Ready**

- Style: **Human-readable, non-technical**

- Coverage: **All teacher-visible UI**

- Safe for: **AI-assisted sync with `Localizable.xcstrings`**# LocalizationFix.md
  
  ## Final Submission · Comprehensive & Optimized
  
  > **Authoritative localization specification for EarthLord**
  > 
  > This document defines the **final, human-readable UI copy** for the application.  
  > All keys listed here are considered **stable** and **must not be renamed**.
  > 
  > This file is the **single source of truth** for localization synchronization.
  
  ---
  
  ## 🏗️ Building System (Day 29)
  
  | Key                             | Chinese (Simplified) | English                | Notes                     |
  | ------------------------------- | -------------------- | ---------------------- | ------------------------- |
  | building_start_construction     | 开始建造                 | Start Construction     | Primary build action      |
  | building_confirm_construction   | 确认建造                 | Confirm Construction   | Confirmation action       |
  | building_resources_insufficient | 资源不足                 | Insufficient Resources | Disabled / warning state  |
  | building_resources_sufficient   | 资源充足                 | Enough Resources       | Availability indicator    |
  | building_select_location        | 选择位置                 | Select Location        | Placement step            |
  | building_location_selected      | 已选位置                 | Location Selected      | Placement feedback        |
  | building_construction_success   | 建造已开始                | Construction Started   | Success toast / banner    |
  | building_max_reached            | 已达建造上限               | Build Limit Reached    | Max-per-territory reached |
  | building_tier_format            | 等级 %lld              | Tier %lld              | Format string             |
  | building_level_format           | 等级 %lld              | Level %lld             | Format string             |
  | building_upgrade                | 升级建筑                 | Upgrade Building       | Upgrade action            |
  | building_upgrade_unavailable    | 无法升级                 | Upgrade Unavailable    | Disabled upgrade state    |
  | building_cancel_construction    | 取消建造                 | Cancel Construction    | Cancel in-progress build  |
  
  ---
  
  ## 🧱 Building Categories
  
  | Key                 | Chinese (Simplified) | English    | Notes          |
  | ------------------- | -------------------- | ---------- | -------------- |
  | category_survival   | 生存设施                 | Survival   | Category label |
  | category_storage    | 储存设施                 | Storage    | Category label |
  | category_production | 生产设施                 | Production | Category label |
  | category_energy     | 能源设施                 | Energy     | Category label |
  
  ---
  
  ## 🗺️ Territory & Map
  
  | Key                          | Chinese (Simplified) | English                | Notes                  |
  | ---------------------------- | -------------------- | ---------------------- | ---------------------- |
  | territory_buildings          | 领地建筑                 | Territory Buildings    | Section title          |
  | territory_points_format      | 领地积分 %lld            | Territory Points %lld  | Format string          |
  | territory_no_buildings       | 暂无建筑                 | No Buildings Yet       | Empty state            |
  | territory_select             | 选择领地                 | Select Territory       | Navigation action      |
  | territory_rename             | 重命名领地                | Rename Territory       | Rename action          |
  | territory_rename_placeholder | 输入领地名称               | Enter territory name   | Text field placeholder |
  | territory_rename_success     | 领地名称已更新              | Territory name updated | Success feedback       |
  
  ---
  
  ## 🎒 Inventory & Resources
  
  | Key                       | Chinese (Simplified) | English              | Notes          |
  | ------------------------- | -------------------- | -------------------- | -------------- |
  | inventory_resources       | 资源                   | Resources            | Section title  |
  | inventory_empty           | 暂无资源                 | No Resources         | Empty state    |
  | inventory_capacity        | 容量                   | Capacity             | Inventory stat |
  | inventory_capacity_format | 容量 %lld / %lld       | Capacity %lld / %lld | Format string  |
  | resource_wood             | 木材                   | Wood                 | Resource name  |
  | resource_stone            | 石头                   | Stone                | Resource name  |
  | resource_metal            | 金属                   | Metal                | Resource name  |
  | resource_concrete         | 混凝土                  | Concrete             | Resource name  |
  | resource_glass            | 玻璃                   | Glass                | Resource name  |
  
  ---
  
  ## 🧭 Navigation & Common UI
  
  | Key            | Chinese (Simplified) | English | Notes             |
  | -------------- | -------------------- | ------- | ----------------- |
  | common_confirm | 确认                   | Confirm | Generic action    |
  | common_cancel  | 取消                   | Cancel  | Generic action    |
  | common_close   | 关闭                   | Close   | Generic action    |
  | common_back    | 返回                   | Back    | Navigation        |
  | common_done    | 完成                   | Done    | Completion action |
  | common_edit    | 编辑                   | Edit    | Edit action       |
  | common_save    | 保存                   | Save    | Save action       |
  
  ---
  
  ## 👤 Profile & Settings
  
  | Key                            | Chinese (Simplified) | English                                                        | Notes               |
  | ------------------------------ | -------------------- | -------------------------------------------------------------- | ------------------- |
  | profile_title                  | 个人资料                 | Profile                                                        | Section title       |
  | profile_settings               | 设置                   | Settings                                                       | Navigation          |
  | profile_delete_confirm_title   | 删除确认                 | Delete Confirmation                                            | Dialog title        |
  | profile_delete_confirm_message | 确定要删除吗？此操作无法撤销。      | Are you sure you want to delete? This action cannot be undone. | Confirmation prompt |
  | profile_logout                 | 退出登录                 | Log Out                                                        | Logout action       |
  
  ---
  
  ## ⚠️ Status & Empty States
  
  | Key            | Chinese (Simplified) | English              | Notes               |
  | -------------- | -------------------- | -------------------- | ------------------- |
  | status_loading | 加载中…                 | Loading…             | Loading state       |
  | status_error   | 出现错误                 | Something went wrong | Generic error       |
  | status_retry   | 重试                   | Retry                | Retry action        |
  | empty_no_data  | 暂无数据                 | No Data Available    | Generic empty state |
