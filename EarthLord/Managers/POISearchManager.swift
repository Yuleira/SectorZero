//
//  POISearchManager.swift
//  EarthLord
//
//  POI搜索管理器
//  使用MapKit搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

/// 附近POI数据模型
struct NearbyPOI: Identifiable, Equatable {
    let id: String
    let name: String
    let type: POIType
    let coordinate: CLLocationCoordinate2D
    var isScavenged: Bool = false

    static func == (lhs: NearbyPOI, rhs: NearbyPOI) -> Bool {
        lhs.id == rhs.id
    }
}

/// POI类型枚举
enum POIType: String, CaseIterable {
    case store = "商店"
    case hospital = "医院"
    case pharmacy = "药店"
    case gasStation = "加油站"
    case restaurant = "餐厅"
    case cafe = "咖啡店"
    case supermarket = "超市"
    case convenience = "便利店"

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .store: return "cart.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .supermarket: return "basket.fill"
        case .convenience: return "bag.fill"
        }
    }

    /// 显示颜色
    var color: String {
        switch self {
        case .store: return "blue"
        case .hospital: return "red"
        case .pharmacy: return "green"
        case .gasStation: return "orange"
        case .restaurant: return "purple"
        case .cafe: return "brown"
        case .supermarket: return "cyan"
        case .convenience: return "indigo"
        }
    }

    /// MapKit 搜索查询关键词
    var searchQuery: String {
        switch self {
        case .store: return "store"
        case .hospital: return "hospital"
        case .pharmacy: return "pharmacy"
        case .gasStation: return "gas station"
        case .restaurant: return "restaurant"
        case .cafe: return "cafe"
        case .supermarket: return "supermarket"
        case .convenience: return "convenience store"
        }
    }

    /// MKPointOfInterestCategory（如果有对应的）
    var poiCategory: MKPointOfInterestCategory? {
        switch self {
        case .store: return .store
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .supermarket: return nil  // 没有直接对应的category
        case .convenience: return nil
        }
    }
}

/// POI搜索管理器
@MainActor
final class POISearchManager {

    // MARK: - 单例

    static let shared = POISearchManager()

    // MARK: - 配置常量

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 每种类型最大结果数
    private let maxResultsPerType: Int = 5

    // MARK: - 初始化

    private init() {
        print("🔍 [POI搜索] 初始化完成")
    }

    // MARK: - 公共方法

    /// 搜索附近POI
    /// - Parameter center: 搜索中心点
    /// - Returns: 附近POI列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D) async -> [NearbyPOI] {
        print("🔍 [POI搜索] 开始搜索，中心点: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")

        var allPOIs: [NearbyPOI] = []

        // 搜索多种类型的POI
        let typesToSearch: [POIType] = [.supermarket, .convenience, .hospital, .pharmacy, .gasStation, .restaurant, .cafe]

        // 并发搜索所有类型
        await withTaskGroup(of: [NearbyPOI].self) { group in
            for poiType in typesToSearch {
                group.addTask {
                    await self.searchPOIs(type: poiType, center: center)
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（基于ID）
        var seen = Set<String>()
        allPOIs = allPOIs.filter { poi in
            if seen.contains(poi.id) {
                return false
            }
            seen.insert(poi.id)
            return true
        }

        // 按距离排序
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        allPOIs.sort { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return loc1.distance(from: centerLocation) < loc2.distance(from: centerLocation)
        }

        // 限制总数（最多20个，因为地理围栏限制）
        if allPOIs.count > 20 {
            allPOIs = Array(allPOIs.prefix(20))
        }

        print("🔍 [POI搜索] 搜索完成，共找到 \(allPOIs.count) 个POI")
        return allPOIs
    }

    // MARK: - 私有方法

    /// 搜索指定类型的POI
    private func searchPOIs(type: POIType, center: CLLocationCoordinate2D) async -> [NearbyPOI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = type.searchQuery
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        // 设置结果类型为POI
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            let pois = response.mapItems.prefix(maxResultsPerType).compactMap { item -> NearbyPOI? in
                guard let name = item.name else { return nil }

                // 计算距离，过滤超出范围的
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let distance = itemLocation.distance(from: centerLocation)

                guard distance <= searchRadius else { return nil }

                // 生成唯一ID
                let id = "\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)_\(name)"
                    .replacingOccurrences(of: " ", with: "_")

                return NearbyPOI(
                    id: id,
                    name: name,
                    type: type,
                    coordinate: item.placemark.coordinate
                )
            }

            print("🔍 [POI搜索] \(type.rawValue): 找到 \(pois.count) 个")
            return Array(pois)
        } catch {
            print("🔍 [POI搜索] \(type.rawValue) 搜索失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 计算两点之间的距离
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}
