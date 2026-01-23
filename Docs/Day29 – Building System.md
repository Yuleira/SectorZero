# Day 29 – Building System

## Full UI Layer & Map Integration

> **Day 29 Scope:** Building browsing, construction confirmation, map-based placement, territory building list, and global map building rendering  
> **Status:** Fully implemented (including detailed pitfall notes)

---

## 1. Feature Overview



### 1.1 Core Feature Checklist

| Module                        | Feature                                                           | Status |
| ----------------------------- | ----------------------------------------------------------------- | ------ |
| **Building Browser**          | Category filtering, grid-based building cards                     | ✅ Done |
| **Building Detail**           | Full information display, entry point for construction            | ✅ Done |
| **Construction Confirmation** | Map-based placement, resource validation, start construction      | ✅ Done |
| **Map Location Picker**       | Territory **polygon** boundary, tap-to-select, existing buildings | ✅ Done |
| **Territory Building List**   | Display buildings, status, progress, countdown                    | ✅ Done |
| **Upgrade / Demolish**        | Context menu, confirmation dialogs                                | ✅ Done |
| **Territory Renaming**        | Gear button, dialog, notification refresh                         | ✅ Done |
| **Global Map Rendering**      | Render buildings on the main map                                  | ✅ Done |
| **Developer Test Tools**      | Add / clear test resources                                        | ✅ Done |

---

### 1.2 Key Differences from Earlier Design

| Issue                       | Previous Approach    | Final / Correct Approach                  |
| --------------------------- | -------------------- | ----------------------------------------- |
| **Territory Shape**         | Circular `MapCircle` | **Polygon-based `MKPolygon`**             |
| **Location Validation**     | Distance from center | **Point-in-polygon algorithm**            |
| **Territory Building List** | Not implemented      | Displayed in territory detail             |
| **Building Status UI**      | None                 | Status badge, progress ring, countdown    |
| **Main Map Buildings**      | None                 | Building annotations rendered             |
| **Real-time Updates**       | None                 | Timer-based construction completion check |

---

## 2. File Inventory

### 2.1 Newly Created Files

| File                               | Path               | Description                       |
| ---------------------------------- | ------------------ | --------------------------------- |
| `BuildingBrowserView.swift`        | `Views/Building/`  | Browser with category tabs + grid |
| `BuildingDetailView.swift`         | `Views/Building/`  | Building detail page              |
| `BuildingPlacementView.swift`      | `Views/Building/`  | Construction confirmation         |
| `BuildingLocationPickerView.swift` | `Views/Building/`  | UIKit-based MKMapView picker      |
| `BuildingCard.swift`               | `Views/Building/`  | Building card component           |
| `CategoryButton.swift`             | `Views/Building/`  | Category selector button          |
| `ResourceRow.swift`                | `Views/Building/`  | Resource cost row                 |
| `TerritoryBuildingRow.swift`       | `Views/Building/`  | Territory building row with menu  |
| `TerritoryMapView.swift`           | `Views/Territory/` | Territory map (UIKit)             |
| `TerritoryToolbarView.swift`       | `Views/Territory/` | Floating toolbar                  |

---

### 2.2 Modified Files

| File                         | Changes                                                     |
| ---------------------------- | ----------------------------------------------------------- |
| `TerritoryDetailView.swift`  | **Fully rewritten**: fullscreen map + building list + menus |
| `TerritoryTabView.swift`     | Added NotificationCenter listeners                          |
| `TerritoryManager.swift`     | Added `updateTerritoryName` + notifications                 |
| `BuildingManager.swift`      | Added `demolishBuilding()`                                  |
| `BuildingModels.swift`       | Added `buildProgress`, `formattedRemainingTime`             |
| `MapViewRepresentable.swift` | Added building annotation rendering (coord fix)             |

---

## 3. Critical Pitfalls & Lessons Learned

### 3.1 Coordinate Conversion Bug (Most Critical)

#### Symptom

Buildings appeared ~500m offset from the territory polygon.

#### Root Cause

**Coordinates stored in the database were already GCJ-02**,  
but the code converted them again, causing double conversion.

#### Incorrect Code

`// ❌ Wrong: coordinates already GCJ-02 let gcj02Coord = CoordinateConverter.wgs84ToGcj02(     latitude: building.locationLat,     longitude: building.locationLon ) annotation.coordinate = gcj02Coord`

#### Correct Code

`// ✅ Correct: use DB coordinates directly guard let coord = building.coordinate else { continue } // Database stores GCJ-02, no conversion needed annotation.coordinate = coord`

#### Affected Files

1. `TerritoryMapView.swift`

2. `MapViewRepresentable.swift`

3. `BuildingLocationPickerView.swift`

#### Debug Tip

`print("🏗️ Building coord: \(building.locationLat), \(building.locationLon)") print("🗺️ Territory center: \(territory.center)") // ~0.005 degrees ≈ 500m → conversion bug`

#### Final Rule

> **Store GCJ-02 → Render GCJ-02 → Never convert again**

---

### 3.2 Existing Buildings Not Visible in Location Picker

**Problem:**  
New buildings could overlap existing ones.

**Solution:**  
Pass existing buildings into `BuildingLocationPickerView` and render annotations.

`struct BuildingLocationPickerView: View {    let territoryCoordinates: [CLLocationCoordinate2D]    let existingBuildings: [PlayerBuilding]    let buildingTemplates: [String: BuildingTemplate] }`

---

### 3.3 Territory Rename Not Refreshing List

**Cause:**  
Only the detail view state was updated.

**Fix:**  
Use `NotificationCenter` to notify the parent list.

---

### 3.4 Sheet Management: `item` vs `isPresented`

**Problem:**  
`isPresented` failed to pass fresh data.

**Correct Pattern:**

`@State private var selectedTemplateForConstruction: BuildingTemplate? .sheet(item: $selectedTemplateForConstruction) { template in     BuildingPlacementView(template: template, ...) }`

---

### 3.5 Browser → Placement Transition Timing

**Problem:**  
Sheet animation conflicts.

**Solution:**  
Delay opening the second sheet by 0.3s after closing the first.

---

## 4. View Hierarchy & Sheet Architecture

`TerritoryDetailView (fullscreen map)  ├─ TerritoryMapView (polygon + buildings)  ├─ TerritoryToolbarView (top floating)  └─ Bottom Info Panel      └─ TerritoryBuildingRow list Build Button  ↓ BuildingBrowserView (Sheet 1)  ↓ (0.3s delay) BuildingPlacementView (Sheet 2)  ↓ BuildingLocationPickerView (Sheet 3)`

---

## 5. Key Implementation Details

### 5.1 Polygon Rendering & Point-in-Polygon Validation

Ray casting algorithm used to validate placement inside territory polygon.

---

### 5.2 Fullscreen Territory Detail Layout

`ZStack` with map as background, floating toolbar, collapsible bottom panel.

---

### 5.3 Territory Building Row Actions

- Active buildings → menu (upgrade / demolish)

- Constructing → progress ring + countdown

---

### 5.4 Global Map Building Rendering

Buildings rendered as annotations using **stored GCJ-02 coordinates directly**.

---

## 6. Data Model Extensions

### 6.1 Construction Progress

`var buildProgress: Double { ... } var formattedRemainingTime: String { ... }`

---

### 6.2 BuildingStatus Display Properties

Status → localized display name + color mapping.

---

## 7. Developer Testing Utilities

Debug-only helpers in `InventoryManager`:

- Add test resources

- Clear inventory

---

## 8. Acceptance Criteria

✔ Full build flow  
✔ Polygon-based placement  
✔ Resource validation  
✔ Real-time progress  
✔ Territory rename refresh  
✔ Correct global map rendering

---

## 9. Pitfall Summary

| Issue                 | Cause                        | Fix                     |
| --------------------- | ---------------------------- | ----------------------- |
| 500m offset           | Double coordinate conversion | Use DB coords directly  |
| Overlapping buildings | No existing markers          | Pass & render buildings |
| Rename not refreshing | No parent notification       | NotificationCenter      |
| Sheet data loss       | `isPresented`                | `sheet(item:)`          |
| Animation conflict    | Overlapping sheets           | 0.3s delay              |

**Day 29 – Building System UI & Map Integration**  
**Version 4.0 – Fully Implemented with Pitfall Documentation**
