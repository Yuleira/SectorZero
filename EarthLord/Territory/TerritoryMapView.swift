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

        // 3. 添加放置模式选中位置标注
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

        // 渲染建筑标注 — 自定义六角底座 + 辉光
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

            let identifier = "TacticalBuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 生成渐变圆角徽章 + 白色图标的合成图像
            let isActive = buildingAnnotation.building.status == .active
            let template = buildingAnnotation.template
            let gradientColors = categoryGradientColors(for: template)
            let iconName = template?.icon ?? "building.2.fill"

            let size = CGSize(width: 56, height: 56)
            let renderer = UIGraphicsImageRenderer(size: size)

            let compositeImage = renderer.image { ctx in
                let context = ctx.cgContext
                let rect = CGRect(origin: .zero, size: size)
                // Inset for shadow + glow space
                let badgeRect = rect.insetBy(dx: 4, dy: 4)
                let cornerRadius: CGFloat = 12
                let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)

                // 3D 阴影
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.3).cgColor)

                // Active 建筑：外层分类色辉光
                if isActive {
                    context.setShadow(offset: CGSize(width: 0, height: 3), blur: 10, color: gradientColors.glow.withAlphaComponent(0.5).cgColor)
                }

                // 渐变填充（左上→右下）
                context.saveGState()
                badgePath.addClip()
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(
                    colorsSpace: colorSpace,
                    colors: [gradientColors.top.cgColor, gradientColors.bottom.cgColor] as CFArray,
                    locations: [0.0, 1.0]
                ) {
                    context.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: badgeRect.minX, y: badgeRect.minY),
                        end: CGPoint(x: badgeRect.maxX, y: badgeRect.maxY),
                        options: []
                    )
                }
                context.restoreGState()

                // 白色边框 2pt, 80% opacity
                let borderColor = UIColor.white.withAlphaComponent(0.8)
                borderColor.setStroke()
                badgePath.lineWidth = 2
                badgePath.stroke()

                context.restoreGState()

                // 白色 SF Symbol 图标 24pt semibold
                let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
                if let iconImage = UIImage(systemName: iconName, withConfiguration: iconConfig) {
                    let tinted = iconImage.withTintColor(.white, renderingMode: .alwaysOriginal)
                    let iconSize = tinted.size
                    let iconOrigin = CGPoint(
                        x: (size.width - iconSize.width) / 2,
                        y: (size.height - iconSize.height) / 2
                    )
                    tinted.draw(at: iconOrigin)
                }
            }

            annotationView?.image = compositeImage
            annotationView?.centerOffset = CGPoint(x: 0, y: -28)

            // Active 建筑的脉冲动画
            if isActive {
                addPulseAnimation(to: annotationView!)
            } else {
                annotationView?.layer.removeAllAnimations()
                annotationView?.alpha = 0.75
            }

            return annotationView
        }

        // MARK: - Helper: 脉冲动画

        private func addPulseAnimation(to view: UIView) {
            // 避免重复添加
            guard view.layer.animation(forKey: "tacticalPulse") == nil else { return }

            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.7
            pulse.duration = 1.5
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(pulse, forKey: "tacticalPulse")
        }

        // MARK: - Helper: 建筑分类渐变色 + 辉光色

        private func categoryGradientColors(for template: BuildingTemplate?) -> (top: UIColor, bottom: UIColor, glow: UIColor) {
            guard let category = template?.category else {
                let gray = UIColor.gray
                return (gray, gray.withAlphaComponent(0.7), gray)
            }
            switch category {
            case .survival:
                return (
                    UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1),
                    UIColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1),
                    UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
                )
            case .storage:
                return (
                    UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1),
                    UIColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1),
                    UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
                )
            case .production:
                return (
                    UIColor(red: 0.4, green: 0.3, blue: 0.85, alpha: 1),
                    UIColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 1),
                    UIColor(red: 0.5, green: 0.3, blue: 0.85, alpha: 1)
                )
            case .energy:
                return (
                    UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1),
                    UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1),
                    UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
                )
            }
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
