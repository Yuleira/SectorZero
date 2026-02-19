//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心页面 - Day 36 完整实现
//  显示所有订阅频道的消息聚合
//

import SwiftUI
internal import Auth

struct MessageCenterView: View {
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var isLoading = true
    @State private var selectedChannel: CommunicationChannel?
    @State private var showingChat = false
    @State private var showingOfficialChannel = false

    // Channel management state
    @State private var channelToManage: CommunicationChannel?
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirm = false
    @State private var newChannelName = ""

    private var summaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    private var currentUserId: UUID? {
        authManager.currentUser?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Content
                    if isLoading {
                        loadingView
                    } else if summaries.isEmpty {
                        emptyStateView
                    } else {
                        messageListView
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .navigationDestination(isPresented: $showingChat) {
                if let channel = selectedChannel {
                    ChannelChatView(
                        channel: channel,
                        authManager: authManager,
                        communicationManager: communicationManager
                    )
                }
            }
            .navigationDestination(isPresented: $showingOfficialChannel) {
                if let channel = selectedChannel {
                    OfficialChannelDetailView(channel: channel)
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text(LocalizedString.messageCenter)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer()

            // Refresh button
            Button(action: { loadData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text(LocalizedString.commonLoading)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(LocalizedString.noMessages)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(LocalizedString.subscribeToSeeMessages)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Spacer()
        }
        .padding()
    }

    // MARK: - Message List View

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(summaries) { summary in
                    Button(action: {
                        selectedChannel = summary.channel
                        // Route based on channel type
                        if summary.channel.channelType == .official {
                            showingOfficialChannel = true
                        } else {
                            showingChat = true
                        }
                    }) {
                        MessageRowView(summary: summary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        // Only show management options for channels owned by current user
                        // and NOT for official channels
                        if summary.channel.creatorId == currentUserId,
                           summary.channel.channelType != .official {
                            Button {
                                channelToManage = summary.channel
                                newChannelName = summary.channel.name
                                showingRenameAlert = true
                            } label: {
                                Label(String(localized: LocalizedString.actionRenameChannel), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                channelToManage = summary.channel
                                showingDeleteConfirm = true
                            } label: {
                                Label(String(localized: LocalizedString.actionDeleteChannel), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .alert(String(localized: LocalizedString.renameAlertTitle), isPresented: $showingRenameAlert) {
            TextField(String(localized: LocalizedString.renameAlertTitle), text: $newChannelName)
            Button(String(localized: LocalizedString.commonCancel), role: .cancel) {
                channelToManage = nil
            }
            Button(String(localized: LocalizedString.commonSave)) {
                renameChannel()
            }
        }
        .alert(String(localized: LocalizedString.deleteChannelConfirm), isPresented: $showingDeleteConfirm) {
            Button(String(localized: LocalizedString.commonCancel), role: .cancel) {
                channelToManage = nil
            }
            Button(String(localized: LocalizedString.commonDelete), role: .destructive) {
                deleteChannel()
            }
        } message: {
            if let channel = channelToManage {
                Text(channel.name)
            }
        }
    }

    // MARK: - Methods

    private func loadData() {
        isLoading = true

        Task {
            if let userId = authManager.currentUser?.id {
                // Load subscribed channels
                await communicationManager.loadSubscribedChannels(userId: userId)
                // Load latest messages for all channels
                await communicationManager.loadAllChannelLatestMessages()
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func renameChannel() {
        guard let channel = channelToManage,
              !newChannelName.trimmingCharacters(in: .whitespaces).isEmpty else {
            channelToManage = nil
            return
        }

        Task {
            let success = await communicationManager.updateChannel(
                channelId: channel.id,
                newName: newChannelName.trimmingCharacters(in: .whitespaces)
            )

            await MainActor.run {
                if success {
                    debugLog("✅ [MessageCenter] Channel renamed: \(newChannelName)")
                }
                channelToManage = nil
                newChannelName = ""
            }
        }
    }

    private func deleteChannel() {
        guard let channel = channelToManage else {
            return
        }

        Task {
            let success = await communicationManager.deleteChannel(channelId: channel.id)

            await MainActor.run {
                if success {
                    debugLog("✅ [MessageCenter] Channel deleted: \(channel.name)")
                }
                channelToManage = nil
            }
        }
    }
}

#Preview {
    MessageCenterView()
}
