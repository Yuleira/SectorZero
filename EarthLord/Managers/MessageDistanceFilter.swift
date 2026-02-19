//
//  MessageDistanceFilter.swift
//  EarthLord
//
//  Day 35-B: 距离过滤器
//  集中管理消息的距离过滤逻辑
//
//  ═══════════════════════════════════════════════════════════════════
//  DEBUG 环境变量（Xcode → Edit Scheme → Run → Environment Variables）
//  ═══════════════════════════════════════════════════════════════════
//
//  【距离覆盖】
//  DEBUG_DISTANCE_KM = 2.5       → 强制距离为 2.5km（跳过真实 GPS 计算）
//
//  【阈值反向验证】用于近距离设备测试远距离过滤
//  DEBUG_MAX_RANGE_KM = 0.05     → 强制最大范围为 50 米（覆盖设备矩阵）
//  DEBUG_MAX_RANGE_KM = 0.001    → 强制最大范围为 1 米（几乎必被过滤）
//
//  【保守策略测试】
//  DEBUG_NO_SENDER_LOCATION=1    → 模拟发送者无位置
//  DEBUG_NO_MY_GPS=1             → 模拟接收者无 GPS
//
//  【设备矩阵测试】
//  DEBUG_MY_DEVICE=radio         → 强制我为收音机（接收所有）
//  DEBUG_MY_DEVICE=walkie_talkie → 强制我为对讲机
//  DEBUG_MY_DEVICE=camp_radio    → 强制我为营地电台
//  DEBUG_MY_DEVICE=satellite     → 强制我为卫星通讯
//
//  ═══════════════════════════════════════════════════════════════════

import Foundation
import CoreLocation

// MARK: - Filter Result

/// 距离过滤结果
enum DistanceFilterResult: Equatable {
    /// 通过：距离在范围内
    case passed(senderDevice: String, myDevice: String, distanceKm: Double, rangeKm: Double)
    /// 丢弃：距离超出范围
    case discarded(senderDevice: String, myDevice: String, distanceKm: Double, rangeKm: Double)
    /// 收音机用户：不做距离过滤
    case radioUser
    /// 保守策略：消息缺少位置信息
    case conservativeNoSenderLocation
    /// 保守策略：无法获取当前位置
    case conservativeNoGPS
    /// 保守策略：设备信息缺失
    case conservativeNoDevice
    /// 跳过过滤：官方频道
    case skippedOfficial
    /// 收音机不能发送
    case radioCannotSend
}

// MARK: - Message Distance Filter

/// 消息距离过滤器（单例）
/// 负责判断消息是否应该被接收，并输出规范化日志
final class MessageDistanceFilter {

    // MARK: - Singleton

    static let shared = MessageDistanceFilter()
    private init() {
        #if DEBUG
        printDebugConfiguration()
        #endif
    }

    // MARK: - DEBUG Distance Override

    #if DEBUG

    /// 从环境变量获取强制距离值（单位：km）
    /// 当设置时，跳过 CLLocation 计算，直接使用此值
    private var debugDistanceKm: Double? {
        guard let value = ProcessInfo.processInfo.environment["DEBUG_DISTANCE_KM"],
              let distance = Double(value) else {
            return nil
        }
        return distance
    }

    /// 是否模拟发送者无位置
    private var debugNoSenderLocation: Bool {
        ProcessInfo.processInfo.environment["DEBUG_NO_SENDER_LOCATION"] == "1"
    }

    /// 是否模拟接收者无 GPS
    private var debugNoMyGPS: Bool {
        ProcessInfo.processInfo.environment["DEBUG_NO_MY_GPS"] == "1"
    }

    /// 强制我的设备类型
    private var debugMyDevice: DeviceType? {
        guard let value = ProcessInfo.processInfo.environment["DEBUG_MY_DEVICE"] else {
            return nil
        }
        return DeviceType(rawValue: value.lowercased())
    }

    /// 强制覆盖最大通讯范围（单位：km）
    /// 用于「阈值反向验证」：在设备近距离时测试过滤逻辑
    private var debugMaxRangeKm: Double? {
        guard let value = ProcessInfo.processInfo.environment["DEBUG_MAX_RANGE_KM"],
              let range = Double(value) else {
            return nil
        }
        return range
    }

    /// 打印 DEBUG 配置信息
    private func printDebugConfiguration() {
        print("═══════════════════════════════════════════════════════════════")
        print("🧪 [距离过滤] DEBUG 模式已启用")
        if let distance = debugDistanceKm {
            print("🧪 [距离过滤] DEBUG_DISTANCE_KM = \(distance) km (强制距离覆盖)")
        }
        if let range = debugMaxRangeKm {
            print("🧪 [距离过滤] DEBUG_MAX_RANGE_KM = \(range) km (阈值反向验证)")
        }
        if debugNoSenderLocation {
            print("🧪 [距离过滤] DEBUG_NO_SENDER_LOCATION = 1 (模拟发送者无位置)")
        }
        if debugNoMyGPS {
            print("🧪 [距离过滤] DEBUG_NO_MY_GPS = 1 (模拟接收者无GPS)")
        }
        if let device = debugMyDevice {
            print("🧪 [距离过滤] DEBUG_MY_DEVICE = \(device.rawValue)")
        }
        let hasAnyOverride = debugDistanceKm != nil || debugMaxRangeKm != nil ||
                             debugNoSenderLocation || debugNoMyGPS || debugMyDevice != nil
        if !hasAnyOverride {
            print("🧪 [距离过滤] 无调试覆盖，使用真实逻辑")
        }
        print("═══════════════════════════════════════════════════════════════")
    }

    #endif

    // MARK: - Public API

    /// 判断消息是否应该被接收
    /// - Parameters:
    ///   - message: 收到的消息
    ///   - channelType: 频道类型
    ///   - myDevice: 我的当前设备
    ///   - myLocation: 我的当前位置（可选）
    /// - Returns: (shouldReceive: 是否接收, result: 过滤结果)
    func shouldReceive(
        message: ChannelMessage,
        channelType: ChannelType,
        myDevice: DeviceType?,
        myLocation: LocationPoint?
    ) -> (shouldReceive: Bool, result: DistanceFilterResult) {

        // 实际过滤逻辑（DEBUG 覆盖在内部处理）
        return performFilter(
            message: message,
            channelType: channelType,
            myDevice: myDevice,
            myLocation: myLocation
        )
    }

    /// 输出规范化日志
    func logResult(_ result: DistanceFilterResult) {
        switch result {
        case .passed(let sender, let my, let distance, let range):
            debugLog("✅ [距离过滤] 通过: 发送者=\(sender), 我=\(my), 距离=\(String(format: "%.2f", distance))km, 范围=\(String(format: "%.2f", range))km")

        case .discarded(let sender, let my, let distance, let range):
            debugLog("🚫 [距离过滤] 丢弃: 发送者=\(sender), 我=\(my), 距离=\(String(format: "%.2f", distance))km, 超出范围=\(String(format: "%.2f", range))km")

        case .radioUser:
            debugLog("📻 [距离过滤] 收音机用户，接收所有消息")

        case .conservativeNoSenderLocation:
            debugLog("⚠️ [距离过滤] 消息缺少位置信息，保守显示")

        case .conservativeNoGPS:
            debugLog("⚠️ [距离过滤] 无法获取当前位置，保守显示")

        case .conservativeNoDevice:
            debugLog("⚠️ [距离过滤] 设备信息缺失，保守显示")

        case .skippedOfficial:
            debugLog("📢 [距离过滤] 官方频道，跳过过滤")

        case .radioCannotSend:
            debugLog("🚫 [发送限制] 收音机模式不可发送")
        }
    }

    // MARK: - Private Implementation

    /// 执行实际的过滤逻辑
    private func performFilter(
        message: ChannelMessage,
        channelType: ChannelType,
        myDevice: DeviceType?,
        myLocation: LocationPoint?
    ) -> (shouldReceive: Bool, result: DistanceFilterResult) {

        // Rule 1: 官方频道跳过过滤
        if channelType == .official {
            return (true, .skippedOfficial)
        }

        // 解析我的设备（DEBUG 可覆盖）
        let resolvedMyDevice = resolveMyDevice(myDevice)

        // Rule 2: 收音机用户接收所有消息
        if resolvedMyDevice == .radio {
            return (true, .radioUser)
        }

        // Rule 3: 保守策略 - 我的设备缺失
        guard let myDeviceType = resolvedMyDevice else {
            return (true, .conservativeNoDevice)
        }

        #if DEBUG
        // DEBUG: 强制模拟发送者无位置
        if debugNoSenderLocation {
            return (true, .conservativeNoSenderLocation)
        }

        // DEBUG: 强制模拟接收者无 GPS
        if debugNoMyGPS {
            return (true, .conservativeNoGPS)
        }
        #endif

        // Rule 4: 保守策略 - 发送者位置缺失
        guard message.senderLocation != nil else {
            return (true, .conservativeNoSenderLocation)
        }

        // Rule 5: 保守策略 - 我的位置缺失
        guard myLocation != nil else {
            return (true, .conservativeNoGPS)
        }

        // Rule 6: 保守策略 - 发送者设备类型缺失（默认用对讲机）
        let senderDevice = message.senderDeviceType ?? .walkieTalkie

        // Day 35-C: Get coordinates for logging
        let senderLoc = message.senderLocation!
        let myLoc = myLocation!

        // 计算距离（DEBUG 可覆盖）
        let distanceKm = resolveDistance(message: message, myLocation: myLoc)
        let rangeKm = getEffectiveRange(senderDevice: senderDevice, myDevice: myDeviceType)

        // Step 4: Logging Protocol (STRICT)
        debugLog("[DistanceFilter] sender=(\(String(format: "%.4f", senderLoc.latitude)),\(String(format: "%.4f", senderLoc.longitude))), me=(\(String(format: "%.4f", myLoc.latitude)),\(String(format: "%.4f", myLoc.longitude)))")
        debugLog("[DistanceFilter] distance=\(String(format: "%.2f", distanceKm)) km (Range=\(String(format: "%.2f", rangeKm)) km)")

        // 判断是否在范围内
        if distanceKm <= rangeKm {
            debugLog("[DistanceFilter] ✅ Passed")
            return (true, .passed(
                senderDevice: senderDevice.rawValue,
                myDevice: myDeviceType.rawValue,
                distanceKm: distanceKm,
                rangeKm: rangeKm
            ))
        } else {
            debugLog("[DistanceFilter] 🚫 Filtered")
            return (false, .discarded(
                senderDevice: senderDevice.rawValue,
                myDevice: myDeviceType.rawValue,
                distanceKm: distanceKm,
                rangeKm: rangeKm
            ))
        }
    }

    /// 解析我的设备类型（DEBUG 可覆盖）
    private func resolveMyDevice(_ device: DeviceType?) -> DeviceType? {
        #if DEBUG
        if let debugDevice = debugMyDevice {
            return debugDevice
        }
        #endif
        return device
    }

    /// 解析距离（DEBUG 可覆盖，跳过 CLLocation 计算）
    private func resolveDistance(message: ChannelMessage, myLocation: LocationPoint) -> Double {
        #if DEBUG
        // 如果设置了 DEBUG_DISTANCE_KM，直接使用该值，不调用 CLLocation
        if let override = debugDistanceKm {
            return override
        }
        #endif

        // 真实计算
        guard let senderLocation = message.senderLocation else {
            return 0
        }
        return calculateDistanceKm(from: senderLocation, to: myLocation)
    }

    /// 计算两点之间的距离（公里）
    private func calculateDistanceKm(from point1: LocationPoint, to point2: LocationPoint) -> Double {
        let loc1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
        let loc2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
        return loc1.distance(from: loc2) / 1000.0
    }

    /// 获取有效通讯范围（公里）
    private func getEffectiveRange(senderDevice: DeviceType, myDevice: DeviceType) -> Double {
        #if DEBUG
        // 阈值反向验证：强制覆盖最大范围
        if let override = debugMaxRangeKm {
            print("🧪 [距离过滤] 使用 DEBUG_MAX_RANGE_KM = \(override) km 覆盖设备矩阵")
            return override
        }
        #endif

        // 收音机接收无限
        if myDevice == .radio {
            return Double.infinity
        }

        // 收音机不能发送
        if senderDevice == .radio {
            return 0
        }

        // 设备矩阵
        switch senderDevice {
        case .radio:
            return 0
        case .walkieTalkie:
            switch myDevice {
            case .radio: return Double.infinity
            case .walkieTalkie: return 3.0
            case .campRadio: return 30.0
            case .satellite: return 100.0
            }
        case .campRadio:
            return 30.0
        case .satellite:
            return 100.0
        }
    }
}
