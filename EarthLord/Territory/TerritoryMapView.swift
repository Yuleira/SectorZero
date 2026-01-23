//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图视图（UIKit MKMapView 包装）
//  渲染领地多边形和建筑标注
//  ⚠️ 关键：数据库坐标已是 GCJ-02，直接使用，不要二次转换！
//

import SwiftUI
import MapKit

struct TerritoryMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 清除旧的覆盖层和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // 1. 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            mapView.addOverlay(polygon)
            
            // 设置地图区域以显示整个多边形
            let rect = polygon.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 200, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
        }
        
        // 2. 添加建筑标注
        for building in buildings {
            // ⚠️ 重要：building.locationLat/Lon 已经是 GCJ-02 坐标
            // 直接使用，不要调用 CoordinateConverter！
            guard let coordinate = building.coordinate else { continue }
            
            let annotation = BuildingAnnotation(
                coordinate: coordinate,
                building: building,
                template: buildingTemplates[building.templateId]
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate {
        
        // 渲染多边形覆盖层
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.2)
                renderer.strokeColor = UIColor(ApocalypseTheme.primary)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // 渲染建筑标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? BuildingAnnotation else {
                return nil
            }
            
            let identifier = "BuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // 设置标注样式
            if let template = buildingAnnotation.template {
                // 根据建筑分类设置颜色
                switch template.category {
                case .survival:
                    annotationView?.markerTintColor = UIColor.orange
                case .storage:
                    annotationView?.markerTintColor = UIColor.brown
                case .production:
                    annotationView?.markerTintColor = UIColor.systemIndigo
                case .energy:
                    annotationView?.markerTintColor = UIColor.yellow
                }
                
                annotationView?.glyphImage = UIImage(systemName: template.icon)
            } else {
                annotationView?.markerTintColor = UIColor.gray
                annotationView?.glyphImage = UIImage(systemName: "building.2")
            }
            
            // 根据状态调整不透明度
            if buildingAnnotation.building.status == .constructing {
                annotationView?.alpha = 0.6
            } else {
                annotationView?.alpha = 1.0
            }
            
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
