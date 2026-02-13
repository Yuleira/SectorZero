//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图视图（UIKit MKMapView 包装）
//  渲染领地多边形和建筑标注
//  ⚠️ 关键：数据库坐标已是 GCJ-02，直接使用，不要二次转换！
//
//  Tactical Aurora Theme: Neon green boundary, hex building bases, pulse glow
//

import SwiftUI
import MapKit

struct TerritoryMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]

    /// 放置模式：点击地图的回调（nil = 不可点击）
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    /// 放置模式：选中的放置位置
    var selectedPlacementLocation: CLLocationCoordinate2D?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false

        // 添加点击手势（放置模式用）
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        context.coordinator.tapGesture = tapGesture
        tapGesture.isEnabled = false

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 启用/禁用点击手势
        context.coordinator.onTap = onTap
        context.coordinator.tapGesture?.isEnabled = onTap != nil

        // 1. 更新领地多边形（仅在首次或坐标变化时）
        let existingPolygons = mapView.overlays.compactMap { $0 as? MKPolygon }
        if existingPolygons.isEmpty && territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            mapView.addOverlay(polygon)

            let rect = polygon.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 200, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
        }

        // 2. Diff-based 建筑标注更新（避免全量删除导致闪烁和动画重置）
        let existingBuildings = mapView.annotations.compactMap { $0 as? BuildingAnnotation }
        let existingIds = Set(existingBuildings.map { $0.building.id })
        let newIds = Set(buildings.compactMap { $0.coordinate != nil ? $0.id : nil })

        // 移除不再存在的
        let toRemove = existingBuildings.filter { !newIds.contains($0.building.id) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }

        // 添加新的（跳过已存在的）
        for building in buildings {
            guard let coordinate = building.coordinate else { continue }
            guard !existingIds.contains(building.id) else { continue }
            let annotation = BuildingAnnotation(
                coordinate: coordinate,
                building: building,
                template: buildingTemplates[building.templateId]
            )
            mapView.addAnnotation(annotation)
        }

        // 3. 放置模式选中位置标注（这个可以每次更新）
        let existingPlacement = mapView.annotations.filter { $0 is MKPointAnnotation }
        mapView.removeAnnotations(existingPlacement)
        if let selected = selectedPlacementLocation {
            let selectedAnnotation = MKPointAnnotation()
            selectedAnnotation.coordinate = selected
            selectedAnnotation.title = String(localized: "building_selected_location")
            mapView.addAnnotation(selectedAnnotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {

        var onTap: ((CLLocationCoordinate2D) -> Void)?
        weak var tapGesture: UITapGestureRecognizer?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            // ⚠️ coordinate 来自地图点击，已经是 GCJ-02
            onTap?(coordinate)
        }

        // 渲染多边形覆盖层 — Tactical Aurora 霓虹绿边界
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                // Neon Green 边界 0.8 opacity, 3pt stroke
                renderer.strokeColor = UIColor(ApocalypseTheme.neonGreen).withAlphaComponent(0.8)
                renderer.lineWidth = 3
                // 轻绿渐变填充
                renderer.fillColor = UIColor(ApocalypseTheme.neonGreen).withAlphaComponent(0.08)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // 渲染建筑标注 — 3D SceneKit 全息投影
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 放置模式选中位置标注
            if annotation is MKPointAnnotation {
                let identifier = "PlacementSelectedLocation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }
                annotationView?.markerTintColor = UIColor(ApocalypseTheme.success)
                annotationView?.glyphImage = UIImage(systemName: "checkmark")
                return annotationView
            }

            guard let buildingAnnotation = annotation as? BuildingAnnotation else {
                return nil
            }

            // 3D SceneKit building miniatures
            let identifier = Building3DAnnotationView.reuseID
            var annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier) as? Building3DAnnotationView
            if annotationView == nil {
                annotationView = Building3DAnnotationView(
                    annotation: buildingAnnotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = buildingAnnotation
            }
            annotationView?.configure(with: buildingAnnotation)
            return annotationView
        }
    }
}




// MARK: - Preview

#Preview {
    let sampleCoords = [
        CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4747),
        CLLocationCoordinate2D(latitude: 31.2324, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4727)
    ]

    let sampleBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "Campfire",
        status: .active,
        level: 1,
        locationLat: 31.2310,
        locationLon: 121.4740,
        buildStartedAt: Date().addingTimeInterval(-3600),
        buildCompletedAt: Date().addingTimeInterval(-3540)
    )

    let template = BuildingTemplate(
        id: UUID(),
        templateId: "campfire",
        name: "Campfire",
        category: .survival,
        tier: 1,
        description: "Test",
        icon: "flame.fill",
        requiredResources: [:],
        buildTimeSeconds: 60,
        maxPerTerritory: 3,
        maxLevel: 3
    )

    TerritoryMapView(
        territoryCoordinates: sampleCoords,
        buildings: [sampleBuilding],
        buildingTemplates: ["campfire": template]
    )
}
