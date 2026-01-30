//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯系统管理器
//  负责管理通讯设备的加载、切换和解锁
//

import Foundation
import Combine
import Supabase
import Realtime
import CoreLocation

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.shared.client

    private init() {}

    // MARK: - 加载设备

    /// 加载用户的所有通讯设备
    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    /// 初始化用户的默认设备
    func initializeDevices(userId: UUID) async {
        do {
            try await client.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    /// 切换当前使用的设备
    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            errorMessage = String(localized: LocalizedString.deviceNotUnlocked)
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await client.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备

    /// 解锁设备（由建造系统调用）
    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷方法

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 当前设备是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前设备的通讯范围
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - Channel Properties

    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - Message Properties (Day 34)

    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false

    // MARK: - Realtime Properties
    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?
    @Published var subscribedMessageChannelIds: Set<UUID> = []

    // MARK: - Channel Methods

    /// 加载公共频道（发现页面）
    func loadPublicChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载已订阅的频道（我的频道）
    func loadSubscribedChannels(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 加载订阅记录
            let subscriptions: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            // 如果有订阅，加载对应的频道
            if !subscriptions.isEmpty {
                let channelIds = subscriptions.map { $0.channelId.uuidString }

                let channelResponse: [CommunicationChannel] = try await client
                    .from("communication_channels")
                    .select()
                    .in("id", values: channelIds)
                    .execute()
                    .value

                // 组合频道与订阅信息
                subscribedChannels = subscriptions.compactMap { subscription in
                    guard let channel = channelResponse.first(where: { $0.id == subscription.channelId }) else {
                        return nil
                    }
                    return SubscribedChannel(channel: channel, subscription: subscription)
                }
            } else {
                subscribedChannels = []
            }
        } catch {
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 创建频道
    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async -> UUID? {
        isLoading = true
        errorMessage = nil

        do {
            var params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name": .string(name)
            ]

            if let desc = description, !desc.isEmpty {
                params["p_description"] = .string(desc)
            }

            let response = try await client.rpc("create_channel_with_subscription", params: params).execute()

            // 解析返回的 UUID（与 TradeManager 一致：先按 UTF-8 字符串再 trim 引号）
            let rawString = String(data: response.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))

            if let uuidString = rawString, let channelId = UUID(uuidString: uuidString) {
                await loadSubscribedChannels(userId: userId)
                isLoading = false
                return channelId
            }

            // 备选：按 JSON 单值解码 UUID
            if let uuid = try? JSONDecoder().decode(UUID.self, from: response.data) {
                await loadSubscribedChannels(userId: userId)
                isLoading = false
                return uuid
            }

            // 解析失败：服务器返回格式异常
            errorMessage = "创建频道失败：无法解析服务器返回"
            await loadSubscribedChannels(userId: userId)
            isLoading = false
            return nil
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    /// 订阅频道
    func subscribeToChannel(channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = ["p_channel_id": .string(channelId.uuidString)]
            try await client.rpc("subscribe_to_channel", params: params).execute()

            // 更新本地频道列表中的成员数
            if let index = channels.firstIndex(where: { $0.id == channelId }) {
                _ = channels[index]
                // 由于 CommunicationChannel 是 let，我们需要重新加载
                await loadPublicChannels()
            }
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 取消订阅频道
    func unsubscribeFromChannel(channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = ["p_channel_id": .string(channelId.uuidString)]
            try await client.rpc("unsubscribe_from_channel", params: params).execute()

            // 从本地列表移除
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }

            // 刷新公共频道列表以更新成员数
            await loadPublicChannels()
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 删除频道
    func deleteChannel(channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = ["p_channel_id": .string(channelId.uuidString)]
            try await client.rpc("delete_channel", params: params).execute()

            // 从本地列表移除
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查是否已订阅某频道
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    // MARK: - Message Methods (Day 34)

    /// Load channel history messages
    func loadChannelMessages(channelId: UUID) async {
        do {
            let messages: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            // Day 35-A: Apply distance filtering for public channels
            let channelType = getChannel(byId: channelId)?.channelType ?? .publicChannel
            let myDevice = currentDevice?.deviceType
            let myLocation = getCurrentLocation()
            
            let filteredMessages = messages.filter { message in
                let (shouldReceive, _) = MessageDistanceFilter.shared.shouldReceive(
                    message: message,
                    channelType: channelType,
                    myDevice: myDevice,
                    myLocation: myLocation
                )
                return shouldReceive
            }

            await MainActor.run {
                channelMessages[channelId] = filteredMessages
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
            }
        }
    }

    /// Send channel message
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                errorMessage = "Message content cannot be empty"
            }
            return false
        }

        await MainActor.run {
            isSendingMessage = true
        }

        do {
            print("📤 [SendMessage] Preparing to send - lat: \(latitude ?? -999), lon: \(longitude ?? -999), device: \(deviceType ?? "nil")")

            let params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null,
                "p_device_type": deviceType.map { .string($0) } ?? .null
            ]

            print("📤 [SendMessage] RPC params: \(params)")

            let _: UUID = try await client
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            print("📤 [SendMessage] Message sent successfully!")

            await MainActor.run {
                isSendingMessage = false
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Send failed: \(error.localizedDescription)"
                isSendingMessage = false
            }
            return false
        }
    }

    /// Get messages for a channel
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - Distance Filtering Helper (Day 35-B)

    /// Get current user location from GPS via LocationManager
    /// In DEBUG mode, respects MOCK_LOCATION environment variable for testing
    /// Returns nil if GPS not available (conservative strategy will show message)
    private func getCurrentLocation() -> LocationPoint? {
        #if DEBUG
        // Use provider for mock location support
        if let location = LocationManager.shared.providerLocation {
            return LocationPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return nil
        #else
        // Production: use real GPS only
        guard let coordinate = LocationManager.shared.userLocation else {
            return nil
        }
        return LocationPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        #endif
    }

    /// Get channel by ID from local cache
    private func getChannel(byId channelId: UUID) -> CommunicationChannel? {
        // First check subscribed channels
        if let subscribed = subscribedChannels.first(where: { $0.channel.id == channelId }) {
            return subscribed.channel
        }
        // Then check public channels list
        return channels.first(where: { $0.id == channelId })
    }

    // MARK: - Realtime Subscription (Day 34)

    /// Start Realtime message subscription
    func startRealtimeSubscription() async {
        await stopRealtimeSubscription()

        realtimeChannel = client.realtimeV2.channel("channel_messages_realtime")

        guard let channel = realtimeChannel else { return }

        let insertions = channel.postgresChange(
            InsertAction.self,
            table: "channel_messages"
        )

        messageSubscriptionTask = Task { @MainActor [weak self] in
            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion)
            }
        }

        do {
            try await channel.subscribeWithError()
            print("[Realtime] Message subscription started")
        } catch {
            print("[Realtime] Subscription error: \(error)")
        }
    }

    /// Stop Realtime subscription
    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        print("[Realtime] Message subscription stopped")
    }

    /// Handle new message from Realtime
    private func handleNewMessage(insertion: InsertAction) async {
        do {
            // DEBUG: Print raw payload to verify numerical coordinates
            if let rawData = try? JSONSerialization.data(withJSONObject: insertion.record, options: .prettyPrinted),
               let rawString = String(data: rawData, encoding: .utf8) {
                print("═══════════════════════════════════════════════════════════════")
                print("[Realtime] RAW PAYLOAD:")
                print(rawString)
                print("═══════════════════════════════════════════════════════════════")
            }

            let decoder = JSONDecoder()
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            print("🔔 [Realtime] 收到消息 - channelId: \(message.channelId)")

            guard subscribedMessageChannelIds.contains(message.channelId) else {
                print("[Realtime] 忽略非订阅频道消息: \(message.channelId)")
                return
            }

            // Day 35-B: 使用集中式距离过滤器
            let channelType = getChannel(byId: message.channelId)?.channelType ?? .publicChannel
            let myDevice = currentDevice?.deviceType
            let myLocation = getCurrentLocation()

            let (shouldReceive, filterResult) = MessageDistanceFilter.shared.shouldReceive(
                message: message,
                channelType: channelType,
                myDevice: myDevice,
                myLocation: myLocation
            )

            // 输出规范化日志
            MessageDistanceFilter.shared.logResult(filterResult)

            guard shouldReceive else {
                print("🚫 [Realtime] 消息被过滤: \(message.content.prefix(20))...")
                return
            }

            await MainActor.run {
                if channelMessages[message.channelId] != nil {
                    channelMessages[message.channelId]?.append(message)
                } else {
                    channelMessages[message.channelId] = [message]
                }
            }

            print("✅ [Realtime] 消息已接收: \(message.content.prefix(20))...")
        } catch {
            print("❌ [Realtime] 消息解析失败: \(error)")
        }
    }

    /// Subscribe to channel messages
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedMessageChannelIds.insert(channelId)

        if realtimeChannel == nil {
            Task {
                await startRealtimeSubscription()
            }
        }
    }

    /// Unsubscribe from channel messages
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedMessageChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)

        if subscribedMessageChannelIds.isEmpty {
            Task {
                await stopRealtimeSubscription()
            }
        }
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
