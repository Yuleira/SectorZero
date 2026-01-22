# Day 28: Building System – Data Layer & Core Logic

> Day 28 Development Scope: **Building Models + Building Manager**

---

## 1. What Problem Are We Solving?

In previous stages, we have already implemented:

- **Exploration System**: Players can explore POIs on the map

- **Looting System**: Players can obtain resources (wood, stone, metal, etc.)

- **Inventory System**: Resources are stored in the player’s backpack

- **Territory System**: Players can claim and control territories

Now the key question is:

**What are resources used for?**

The answer is: **Building.**

Imagine a post-apocalyptic scenario:

- You scavenge wood and stone from ruins

- Night falls and temperature drops

- You need a campfire to survive

- You open the build menu, select *Campfire*

- Cost: Wood ×30 + Stone ×20

- The fire lights up — you survive the first night

This is the **Building System**:  
**Resources are converted into structures, giving territory real meaning.**

---

## 2. Core Concept

### Analogy: E-commerce System

The building system is logically **identical to an e-commerce checkout flow**:

| E-commerce               | Building System      |
| ------------------------ | -------------------- |
| Product list             | Building templates   |
| Product price            | Required resources   |
| User balance / inventory | Player resources     |
| Stock check              | Resource validation  |
| Payment deduction        | Resource consumption |
| Order status             | Building status      |

**If you understand the building system, you understand the core logic of e-commerce systems.**

---

### Today’s Scope

Today we implement **data layer and business logic only**:

1. Define data models

2. Create the Building Manager (core logic)

3. Prepare building templates (JSON config)

4. Create database tables

**UI is intentionally excluded** and will be implemented later.

---

## 3. Building Categories

### Four Categories

| Category   | Key        | Icon            | Description         | Examples                  |
| ---------- | ---------- | --------------- | ------------------- | ------------------------- |
| Survival   | survival   | house.fill      | Basic survival      | Campfire, Shelter         |
| Storage    | storage    | archivebox.fill | Item storage        | Small / Medium Storage    |
| Production | production | hammer.fill     | Resource production | Farm, Workbench           |
| Energy     | energy     | bolt.fill       | Energy facilities   | Solar Panel, Wind Turbine |

---

### Three Tiers

| Tier   | Description          | Characteristics             |
| ------ | -------------------- | --------------------------- |
| Tier 1 | Survival basics      | Low cost, beginner friendly |
| Tier 2 | Functional expansion | Medium cost                 |
| Tier 3 | Advanced facilities  | High cost, late game        |

---

## 4. Building Status (State Machine)

### Status Definitions

| Status       | Key          | Color | Description                           |
| ------------ | ------------ | ----- | ------------------------------------- |
| Constructing | constructing | Blue  | Under construction, countdown running |
| Active       | active       | Green | Operational, can be upgraded          |

---

### State Flow

`Tap Build    │    ▼ ┌────────────────┐ │ constructing   │  Under construction │ countdown...   │ └────────────────┘    │ time finished    ▼ ┌────────────────┐ │ active         │  Operational │ upgradeable    │ └────────────────┘    │ upgrade    ▼  level + 1`

---

### Why State Machines Matter

This is a **high-frequency interview topic**.

The same pattern appears everywhere:

- Orders: pending → paid → shipped → delivered

- Users: unregistered → registered → verified → VIP

- Approvals: pending → reviewing → approved / rejected

**Rule**: Available actions depend on the current state.

Example: Only buildings in `active` state can be upgraded.

---

## 5. Data Model Design

### 5.1 BuildingCategory Enum

`enum BuildingCategory: String, Codable, CaseIterable {    case survival = "survival"     case storage = "storage"     case production = "production"     case energy = "energy"      var displayName: String { ... }    var icon: String { ... } }`

---

### 5.2 BuildingStatus Enum

`enum BuildingStatus: String, Codable {    case constructing = "constructing"     case active = "active"      var displayName: String { ... }    var color: Color { ... } }`

---

### 5.3 BuildingTemplate

Defines **what can be built**:

| Field             | Type             | Description       |
| ----------------- | ---------------- | ----------------- |
| id                | UUID             | Unique identifier |
| templateId        | String           | e.g. `"campfire"` |
| name              | String           | Display name      |
| category          | BuildingCategory | Category          |
| tier              | Int              | 1 / 2 / 3         |
| description       | String           | Description       |
| icon              | String           | SF Symbol         |
| requiredResources | [String: Int]    | Cost              |
| buildTimeSeconds  | Int              | Build time        |
| maxPerTerritory   | Int              | Max per territory |
| maxLevel          | Int              | Max upgrade level |

---

### 5.4 PlayerBuilding

Tracks **what the player has built**:

| Field            | Type           |
| ---------------- | -------------- |
| id               | UUID           |
| userId           | UUID           |
| territoryId      | String         |
| templateId       | String         |
| buildingName     | String         |
| status           | BuildingStatus |
| level            | Int            |
| locationLat      | Double?        |
| locationLon      | Double?        |
| buildStartedAt   | Date           |
| buildCompletedAt | Date?          |

---

### 5.5 BuildingError

`enum BuildingError: Error {    case insufficientResources([String: Int])    case maxBuildingsReached(Int)    case templateNotFound    case invalidStatus }`

---

## 6. Building Manager Design

### 6.1 Singleton

`@MainActor class BuildingManager: ObservableObject {    static let shared = BuildingManager()    private init() {} }`

**Why singleton?**

- Single source of truth

- Accessible globally

- Prevents data inconsistency

---

### 6.2 Core Properties

`@Published var buildingTemplates: [BuildingTemplate] = [] @Published var playerBuildings: [PlayerBuilding] = [] @Published var isLoading = false @Published var errorMessage: String?`

---

### 6.3 Core Methods

| Method                    | Purpose                   |
| ------------------------- | ------------------------- |
| loadTemplates()           | Load templates from JSON  |
| canBuild(...)             | Validate build conditions |
| startConstruction(...)    | Start building            |
| completeConstruction(...) | Finish building           |
| upgradeBuilding(...)      | Upgrade                   |
| fetchPlayerBuildings(...) | Load buildings            |

---

### 6.4 canBuild() – Core Validation Logic

`func canBuild(    template: BuildingTemplate,    territoryId: String,    playerResources: [String: Int] ) -> (canBuild: Bool, error: BuildingError?) {    var insufficient: [String: Int] = [:]    for (resource, required) in template.requiredResources {        let available = playerResources[resource] ?? 0         if available < required {             insufficient[resource] = required - available         }     }    if !insufficient.isEmpty {        return (false, .insufficientResources(insufficient))     }    let existingCount = playerBuildings.filter {        $0.territoryId == territoryId &&         $0.templateId == template.templateId     }.count    if existingCount >= template.maxPerTerritory {        return (false, .maxBuildingsReached(template.maxPerTerritory))     }    return (true, nil) }`

---

### 6.5 startConstruction()

`func startConstruction(    templateId: String,    territoryId: String,    location: CLLocationCoordinate2D? ) async -> Result<PlayerBuilding, BuildingError> {    guard let template = buildingTemplates.first(where: { $0.templateId == templateId }) else {        return .failure(.templateNotFound)     }    for (resource, amount) in template.requiredResources {        await InventoryManager.shared.removeItem(resource, quantity: amount)     }    let building = PlayerBuilding(         userId: currentUserId,         territoryId: territoryId,         templateId: templateId,         buildingName: template.name,         status: .constructing,         level: 1,         buildStartedAt: Date(),         buildCompletedAt: Date().addingTimeInterval(Double(template.buildTimeSeconds))     )    // Insert into database     // Start timer      return .success(building) }`

---

### 6.6 upgradeBuilding()

`func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {    guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {        return .failure(.templateNotFound)     }    guard building.status == .active else {        return .failure(.invalidStatus)     }    guard let template = getTemplate(for: building.templateId),           building.level < template.maxLevel else {        return .failure(.maxLevelReached)     }    // level += 1     return .success(updatedBuilding) }`

---

## 7. Building Templates (JSON)

**`building_templates.json`**  
*(content unchanged except language — safe to reuse directly)*

---

## 8. Database Design

### player_buildings Table

`create table player_buildings (   id uuid primary key default gen_random_uuid(),   user_id uuid references auth.users(id) not null,   territory_id text not null,   template_id text not null,   building_name text not null,   status text default 'constructing',   level int default 1,   location_lat double precision,   location_lon double precision,   build_started_at timestamptz default now(),   build_completed_at timestamptz,   created_at timestamptz default now(),   updated_at timestamptz default now() );`

Indexes, RLS policies remain unchanged.

---

## 9. Files to Create

| File                    | Path                | Purpose    |
| ----------------------- | ------------------- | ---------- |
| BuildingModels.swift    | EarthLord/Models    | Models     |
| BuildingManager.swift   | EarthLord/Managers  | Core logic |
| building_templates.json | EarthLord/Resources | Config     |

---

## 10. Acceptance Criteria

- Models correctly defined

- Singleton manager implemented

- JSON loads successfully

- Validation logic works

- Database & RLS configured

---

## 11. Development Notes

- Supabase MCP can auto-create tables

- Xcode 15+ supports filesystem sync

- JSON decoding requires `convertFromSnakeCase`

---

## 12. Summary

Today we completed the **foundation** of the building system:

- Data models

- State machine

- Core validation & construction logic

- Persistent storage

**Next step**: Build UI on top of this system.
