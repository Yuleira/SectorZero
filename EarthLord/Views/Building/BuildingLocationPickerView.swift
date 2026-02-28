//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  建筑位置选择器（UIKit MKMapView）
//  点击地图选择建筑位置，验证是否在领地多边形内
//  ⚠️ 重要：选中的坐标为 GCJ-02，直接保存到数据库
//

import SwiftUI
import MapKit
import CoreLocation

struct BuildingLocationPickerView: View {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    
    var body: some View {
        ZStack {
            // 地图（全屏）
            LocationPickerMapView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: existingBuildings,
                buildingTemplates: buildingTemplates,
                selectedLocation: $selectedLocation,
                onTap: handleMapTap
            )
            .ignoresSafeArea()
            
            // 顶部工具栏
            VStack {
                HStack {
                    // 取消按钮
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedString.commonCancel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    Spacer()
                    
                    // 提示文字
                    Text(LocalizedString.buildingTapToPlace)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                    
                    Spacer()
                    
                    // 占位（对称布局）
                    Color.clear.frame(width: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
            }
            
            // 底部确认按钮
            if selectedLocation != nil {
                VStack {
                    Spacer()
                    
                    Button {
                        if let location = selectedLocation {
                            onLocationSelected(location)
                            dismiss()
                        }
                    } label: {
                        Text(LocalizedString.buildingConfirmLocation)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.primary)
                                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(LocalizedString.buildingLocationInvalid, isPresented: $showValidationError) {
            Button(LocalizedString.commonConfirm, role: .cancel) {}
        } message: {
            Text(validationErrorMessage)
        }
    }
    
    // MARK: - Actions
    
    /// 处理地图点击
    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        // 使用射线法验证点是否在领地多边形内
        let isInsideTerritory = isPointInPolygon(point: coordinate, polygon: territoryCoordinates)

        if isInsideTerritory {
            if isPointNearBoundary(point: coordinate, polygon: territoryCoordinates) {
                validationErrorMessage = String(localized: "building_location_near_boundary")
                showValidationError = true
                debugLog("🗺️ [位置选择] 无效位置：距边界太近")
            } else {
                // ⚠️ coordinate 已经是 GCJ-02，直接使用
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedLocation = coordinate
                }
                debugLog("🗺️ [位置选择] 有效位置: \(coordinate.latitude), \(coordinate.longitude)")
            }
        } else {
            validationErrorMessage = String(localized: "building_location_outside_territory")
            showValidationError = true
            debugLog("🗺️ [位置选择] 无效位置：不在领地内")
        }
    }
    
    // MARK: - Geometry Helpers

    /// 检查点是否距多边形任意边 minDistanceMeters 米内（防止 GPS 抖动漂出）
    private func isPointNearBoundary(
        point: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D],
        minDistanceMeters: Double = 8.0
    ) -> Bool {
        let pt = CLLocation(latitude: point.latitude, longitude: point.longitude)
        for i in 0..<polygon.count {
            let j = (i + 1) % polygon.count
            let a = CLLocation(latitude: polygon[i].latitude, longitude: polygon[i].longitude)
            let b = CLLocation(latitude: polygon[j].latitude, longitude: polygon[j].longitude)
            if distanceFromPointToSegment(pt, a, b) < minDistanceMeters { return true }
        }
        return false
    }

    /// 点到线段（a-b）的最短距离（米）
    private func distanceFromPointToSegment(
        _ pt: CLLocation, _ a: CLLocation, _ b: CLLocation
    ) -> Double {
        let ab = b.distance(from: a)
        guard ab > 0 else { return pt.distance(from: a) }
        let dLat = b.coordinate.latitude  - a.coordinate.latitude
        let dLon = b.coordinate.longitude - a.coordinate.longitude
        let t = max(0, min(1,
            ((pt.coordinate.latitude  - a.coordinate.latitude)  * dLat +
             (pt.coordinate.longitude - a.coordinate.longitude) * dLon)
            / (dLat * dLat + dLon * dLon)
        ))
        let proj = CLLocation(
            latitude:  a.coordinate.latitude  + t * dLat,
            longitude: a.coordinate.longitude + t * dLon
        )
        return pt.distance(from: proj)
    }

    // MARK: - Ray Casting Algorithm (Section 5.1)

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 点是否在多边形内
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        let x = point.longitude
        let y = point.latitude
        
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            
            if intersect {
                inside.toggle()
            }
            j = i
        }
        
        return inside
    }
}

// MARK: - LocationPickerMapView (UIKit Wrapper)

struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    @Binding var selectedLocation: CLLocationCoordinate2D?
    let onTap: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = false
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
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
            
            // 设置地图区域
            let rect = polygon.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: false)
        }
        
        // 2. 添加现有建筑标注
        for building in existingBuildings {
            // ⚠️ building.coordinate 已经是 GCJ-02
            guard let coordinate = building.coordinate else { continue }
            
            let annotation = BuildingAnnotation(
                coordinate: coordinate,
                building: building,
                template: buildingTemplates[building.templateId]
            )
            mapView.addAnnotation(annotation)
        }
        
        // 3. 添加选中位置标注
        if let selected = selectedLocation {
            let selectedAnnotation = MKPointAnnotation()
            selectedAnnotation.coordinate = selected
            selectedAnnotation.title = String(localized: "building_selected_location")
            mapView.addAnnotation(selectedAnnotation)
        }
        
        // 更新 coordinator
        context.coordinator.onTap = onTap
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var onTap: (CLLocationCoordinate2D) -> Void
        
        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // ⚠️ coordinate 来自地图点击，已经是 GCJ-02
            onTap(coordinate)
        }
        
        // 渲染多边形
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
        
        // 渲染标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 处理选中位置标注
            if annotation is MKPointAnnotation {
                let identifier = "SelectedLocation"
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
            
            // 处理建筑标注
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "ExistingBuilding"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                if let template = buildingAnnotation.template {
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
                }
                
                // 半透明显示现有建筑
                annotationView?.alpha = 0.6
                
                return annotationView
            }
            
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    let coords = [
        CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4747),
        CLLocationCoordinate2D(latitude: 31.2324, longitude: 121.4737),
        CLLocationCoordinate2D(latitude: 31.2314, longitude: 121.4727)
    ]
    
    return BuildingLocationPickerView(
        territoryCoordinates: coords,
        existingBuildings: [],
        buildingTemplates: [:],
        onLocationSelected: { coord in
            debugLog("Selected: \(coord)")
        }
    )
}
