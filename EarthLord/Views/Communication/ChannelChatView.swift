//
//  ChannelChatView.swift
//  EarthLord
//
//  频道聊天界面 - Day 34 实现
//  支持消息发送、接收和实时更新
//

import SwiftUI
import CoreLocation
internal import Auth

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @ObservedObject var authManager: AuthManager
    @ObservedObject var communicationManager: CommunicationManager

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Message list
                messageListView

                // Input bar or radio mode hint
                if canSend {
                    inputBar
                } else {
                    radioModeHint
                }
            }

            // Debug overlay showing location mode
            #if DEBUG
            locationModeOverlay
            #endif
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
            communicationManager.subscribeToChannelMessages(channelId: channel.id)
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
        .onChange(of: messages.count) { _, _ in
            scrollToBottom()
        }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyMessageView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == currentUserId,
                                onDelete: message.senderId == currentUserId ? {
                                    deleteMessage(message)
                                } : nil
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
        }
    }

    private var emptyMessageView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(LocalizedString.messageEmpty)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(LocalizedString.messageEmptyHint)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Text field
            TextField(String(localized: LocalizedString.messagePlaceholder), text: $messageText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Send button
            Button(action: sendMessage) {
                Group {
                    if communicationManager.isSendingMessage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .frame(width: 44, height: 44)
                .background(canSendCurrentMessage ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                .clipShape(Circle())
                .foregroundColor(.white)
            }
            .disabled(!canSendCurrentMessage || communicationManager.isSendingMessage)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    private var canSendCurrentMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Radio Mode Hint

    private var radioModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .foregroundColor(ApocalypseTheme.primary)

            Text(LocalizedString.messageRadioModeHint)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Debug Location Overlay

    #if DEBUG
    private var locationModeOverlay: some View {
        let isMock = LocationManager.shared.isUsingMockLocation
        let modeName = LocationManager.shared.locationModeName

        return HStack(spacing: 4) {
            Image(systemName: isMock ? "location.slash.fill" : "location.fill")
                .font(.caption2)
            Text(modeName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isMock ? Color.orange.opacity(0.9) : Color.green.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding(.top, 8)
        .padding(.trailing, 8)
    }
    #endif

    // MARK: - Actions

    private func loadMessages() async {
        await communicationManager.loadChannelMessages(channelId: channel.id)
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        let deviceType = communicationManager.getCurrentDeviceType().rawValue

        // Day 35-B: Get location via provider (supports MOCK_LOCATION env var)
        let latitude: Double?
        let longitude: Double?

        #if DEBUG
        if let location = LocationManager.shared.providerLocation {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            print("📡 [SENDER] Location via provider (\(LocationManager.shared.locationModeName)): lat=\(latitude!), lon=\(longitude!)")
        } else {
            latitude = nil
            longitude = nil
            print("⚠️ [SENDER] WARNING: Provider returned NIL location!")
        }
        #else
        // Production: use real GPS only
        if let coord = LocationManager.shared.userLocation {
            latitude = coord.latitude
            longitude = coord.longitude
        } else {
            latitude = nil
            longitude = nil
        }
        #endif

        debugLog("📡 [SENDER] Sending message - device=\(deviceType), hasLocation=\(latitude != nil)")

        Task {
            debugLog("🚀 [ChannelChatView] Sending message to channel: \(channel.id)")
            
            let success = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                latitude: latitude,
                longitude: longitude,
                deviceType: deviceType
            )

            if success {
                debugLog("✅ [ChannelChatView] Message sent successfully!")
                await MainActor.run {
                    messageText = ""
                }
            } else {
                // Log RPC failure for debugging
                let errorMsg = communicationManager.errorMessage ?? "Unknown error"
                debugLog("❌ [ChannelChatView] SEND FAILED: \(errorMsg)")
            }
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func deleteMessage(_ message: ChannelMessage) {
        guard let senderId = message.senderId else {
            debugLog("❌ [ChannelChatView] Cannot delete: message has no senderId")
            return
        }

        Task {
            let success = await communicationManager.deleteMessage(
                messageId: message.messageId,
                channelId: channel.id,
                senderId: senderId
            )
            if success {
                debugLog("✅ [ChannelChatView] Message deleted: \(message.messageId)")
            }
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // Callsign (for others' messages) - Day 36: Always show with fallback
                if !isOwnMessage {
                    HStack(spacing: 4) {
                        Text(message.formattedCallsign)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(message.hasRegisteredCallsign ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                        // Unregistered indicator
                        if !message.hasRegisteredCallsign {
                            Text("(\(String(localized: LocalizedString.notSet)))")
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }

                        // Device type icon
                        if let deviceType = message.deviceType {
                            deviceIcon(for: deviceType)
                        }
                    }
                }

                // Message content bubble
                messageBubble
                    .contextMenu {
                        if isOwnMessage {
                            Button(role: .destructive) {
                                onDelete?()
                            } label: {
                                Label(String(localized: LocalizedString.commonDelete), systemImage: "trash")
                            }
                        }
                    }
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }

    private var messageBubble: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Text(message.content)
                .font(.body)
                .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)

            // Time
            Text(message.timeAgo)
                .font(.caption2)
                .foregroundColor(isOwnMessage ? .white.opacity(0.7) : ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isOwnMessage ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
        .cornerRadius(18)
    }

    @ViewBuilder
    private func deviceIcon(for deviceType: String) -> some View {
        let iconName: String = {
            switch deviceType {
            case "radio": return "radio"
            case "walkie_talkie": return "flipphone"
            case "camp_radio": return "antenna.radiowaves.left.and.right"
            case "satellite": return "antenna.radiowaves.left.and.right.circle"
            default: return "questionmark.circle"
            }
        }()

        Image(systemName: iconName)
            .font(.caption2)
            .foregroundColor(ApocalypseTheme.textSecondary)
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(
            channel: CommunicationChannel(
                id: UUID(),
                creatorId: UUID(),
                channelType: .publicChannel,
                channelCode: "PUB-ABC123",
                name: "Test Channel",
                description: "Test channel for preview",
                isActive: true,
                memberCount: 10,
                createdAt: Date(),
                updatedAt: Date()
            ),
            authManager: AuthManager.shared,
            communicationManager: CommunicationManager.shared
        )
    }
}
