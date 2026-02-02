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

// 🚀 终极修复：使用 nonisolated 彻底切断与主线程的联系
// 这样它的 Encodable 协议实现就是"非隔离"的，完美符合 Sendable 要求
nonisolated struct ChannelSendMessageParams: Encodable, Sendable {
    let p_channel_id: String
    let p_content: String
    let p_latitude: Double?
    let p_longitude: Double?
    let p_device_type: String?

    // 明确告诉编译器这个 init 也是非隔离的
    nonisolated init(p_channel_id: String, p_content: String, p_latitude: Double?, p_longitude: Double?, p_device_type: String?) {
        self.p_channel_id = p_channel_id
        self.p_content = p_content
        self.p_latitude = p_latitude
        self.p_longitude = p_longitude
        self.p_device_type = p_device_type
    }
}

// Day 36: Official channel subscription params (nonisolated for Sendable compliance)
nonisolated struct OfficialChannelSubscribeParams: Encodable, Sendable {
    let p_channel_id: String

    nonisolated init(p_channel_id: String) {
        self.p_channel_id = p_channel_id
    }
}
///
@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    // MARK: - Day 36: Official Channel Constants

    /// Official channel fixed UUID
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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

    /// 删除频道 (returns success status)
    func deleteChannel(channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = ["p_channel_id": .string(channelId.uuidString)]
            try await client.rpc("delete_channel", params: params).execute()

            // 从本地列表移除
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }
            mySubscriptions.removeAll { $0.channelId == channelId }
            channelMessages.removeValue(forKey: channelId)

            isLoading = false
            print("✅ [Channel] Deleted: \(channelId)")
            return true
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
            isLoading = false
            print("❌ [Channel] Delete failed: \(error)")
            return false
        }
    }

    /// 更新频道名称和描述
    func updateChannel(channelId: UUID, newName: String, newDescription: String? = nil) async -> Bool {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "频道名称不能为空"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // Build update data
            var updateData: [String: AnyJSON] = [
                "name": .string(newName),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            if let desc = newDescription {
                updateData["description"] = .string(desc)
            }

            try await client
                .from("communication_channels")
                .update(updateData)
                .eq("id", value: channelId.uuidString)
                .execute()

            // Update local state immediately
            await MainActor.run {
                // Update in channels array
                if let index = channels.firstIndex(where: { $0.id == channelId }) {
                    let old = channels[index]
                    let updated = CommunicationChannel(
                        id: old.id,
                        creatorId: old.creatorId,
                        channelType: old.channelType,
                        channelCode: old.channelCode,
                        name: newName,
                        description: newDescription ?? old.description,
                        isActive: old.isActive,
                        memberCount: old.memberCount,
                        createdAt: old.createdAt,
                        updatedAt: Date()
                    )
                    channels[index] = updated
                }

                // Update in subscribedChannels array
                if let index = subscribedChannels.firstIndex(where: { $0.channel.id == channelId }) {
                    let old = subscribedChannels[index]
                    let updatedChannel = CommunicationChannel(
                        id: old.channel.id,
                        creatorId: old.channel.creatorId,
                        channelType: old.channel.channelType,
                        channelCode: old.channel.channelCode,
                        name: newName,
                        description: newDescription ?? old.channel.description,
                        isActive: old.channel.isActive,
                        memberCount: old.channel.memberCount,
                        createdAt: old.channel.createdAt,
                        updatedAt: Date()
                    )
                    subscribedChannels[index] = SubscribedChannel(
                        channel: updatedChannel,
                        subscription: old.subscription
                    )
                }
            }

            isLoading = false
            print("✅ [Channel] Updated: \(channelId) -> \(newName)")
            return true
        } catch {
            errorMessage = "更新频道失败: \(error.localizedDescription)"
            isLoading = false
            print("❌ [Channel] Update failed: \(error)")
            return false
        }
    }

    /// 检查是否已订阅某频道
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    // MARK: - Day 36: Official Channel Methods

    /// Check if a channel is the official channel
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        channelId == CommunicationManager.officialChannelId
    }

    /// Ensure user is subscribed to the official channel (forced subscription)
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        let officialId = CommunicationManager.officialChannelId

        // Check if already subscribed
        if subscribedChannels.contains(where: { $0.channel.id == officialId }) {
            print("✅ [官方频道] 已订阅")
            return
        }

        // Force subscribe to official channel
        do {
            let params = OfficialChannelSubscribeParams(p_channel_id: officialId.uuidString)

            try await client.rpc("subscribe_to_channel", params: params).execute()

            // Refresh subscription list
            await loadSubscribedChannels(userId: userId)
            print("✅ [官方频道] 已自动订阅")
        } catch {
            print("❌ [官方频道] 订阅失败: \(error)")
        }
    }

    // MARK: - Day 36: Message Aggregation

    /// Channel summary for message center (latest message + unread count)
    struct ChannelSummary: Identifiable {
        let channel: CommunicationChannel
        let lastMessage: ChannelMessage?
        let unreadCount: Int

        var id: UUID { channel.id }
    }

    /// Get summaries for all subscribed channels (sorted: official first, then by latest message)
    func getChannelSummaries() -> [ChannelSummary] {
        return subscribedChannels.map { subscribedChannel in
            let messages = channelMessages[subscribedChannel.channel.id] ?? []
            let lastMessage = messages.last

            return ChannelSummary(
                channel: subscribedChannel.channel,
                lastMessage: lastMessage,
                unreadCount: 0  // Placeholder: real unread count can be added later
            )
        }.sorted { summary1, summary2 in
            // Official channel always on top
            if summary1.channel.channelType == .official && summary2.channel.channelType != .official {
                return true
            }
            if summary1.channel.channelType != .official && summary2.channel.channelType == .official {
                return false
            }
            // Sort by latest message time
            let time1 = summary1.lastMessage?.createdAt ?? summary1.channel.createdAt
            let time2 = summary2.lastMessage?.createdAt ?? summary2.channel.createdAt
            return time1 > time2
        }
    }

    /// Load latest message for all subscribed channels (for message center preview)
    func loadAllChannelLatestMessages() async {
        for subscribedChannel in subscribedChannels {
            let channelId = subscribedChannel.channel.id

            do {
                let messages: [ChannelMessage] = try await client
                    .from("channel_messages")
                    .select()
                    .eq("channel_id", value: channelId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                if let lastMessage = messages.first {
                    if channelMessages[channelId] == nil {
                        channelMessages[channelId] = [lastMessage]
                    } else if !channelMessages[channelId]!.contains(where: { $0.id == lastMessage.id }) {
                        channelMessages[channelId]?.append(lastMessage)
                    }
                }
            } catch {
                print("❌ [消息聚合] 加载频道 \(channelId) 最新消息失败: \(error)")
            }
        }
        print("✅ [消息聚合] 加载所有频道最新消息完成")
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

    /// 发送频道消息 (终极修复版：杜绝崩溃与并发报错)
        func sendChannelMessage(
            channelId: UUID,
            content: String,
            latitude: Double? = nil,
            longitude: Double? = nil,
            deviceType: String? = nil
        ) async -> Bool {
            // 1. 基础检查
                    guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
                        await MainActor.run { errorMessage = "消息内容不能为空" }
                        return false
                    }

                    await MainActor.run { isSendingMessage = true }

            do {
            // 🚀 2. 使用刚才在类外面定义的高级结构体
                   let params = ChannelSendMessageParams(
                       p_channel_id: channelId.uuidString,
                       p_content: content,
                       p_latitude: latitude,
                       p_longitude: longitude,
                       p_device_type: deviceType
                   )

                print("📤 [SendMessage] RPC 发送中...")
                // 🚀 3. 直接发送 params，此时它是 Sendable 的，编译器会愉快放行
                try await client
                    .rpc("send_channel_message", params: params)
                    .execute()

                await MainActor.run { isSendingMessage = false }
                print("✅ [SendMessage] 发送成功！")
                return true
                
            } catch {
                print("❌ [SendMessage] 发送失败: \(error)")
                await MainActor.run {
                    errorMessage = "发送失败: \(error.localizedDescription)"
                    isSendingMessage = false
                }
                return false
            }
        }

    /// Get messages for a channel
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    /// Delete a message (only sender can delete their own message)
    func deleteMessage(messageId: UUID, channelId: UUID) async -> Bool {
        do {
            try await client
                .from("channel_messages")
                .delete()
                .eq("message_id", value: messageId.uuidString)
                .execute()

            // Remove from local cache
            await MainActor.run {
                channelMessages[channelId]?.removeAll { $0.messageId == messageId }
            }

            print("✅ [Message] Deleted: \(messageId)")
            return true
        } catch {
            print("❌ [Message] Delete failed: \(error)")
            await MainActor.run {
                errorMessage = "删除失败: \(error.localizedDescription)"
            }
            return false
        }
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
