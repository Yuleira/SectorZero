//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心页面 - 我的频道与发现频道
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0  // 0 = 我的频道, 1 = 发现频道
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // Tab 切换栏
            tabBar

            // 搜索栏（仅发现页面）
            if selectedTab == 1 {
                searchBar
            }

            // 内容区域
            contentView
        }
        .background(ApocalypseTheme.background)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text(LocalizedString.channelCenter)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer()

            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: LocalizedString.myChannels, index: 0)
            tabButton(title: LocalizedString.discoverChannels, index: 1)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    private func tabButton(title: LocalizedStringResource, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
            Task { await loadData() }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField(String(localized: LocalizedString.searchChannels), text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content View

    private var contentView: some View {
        Group {
            if communicationManager.isLoading {
                loadingView
            } else if selectedTab == 0 {
                myChannelsView
            } else {
                discoverChannelsView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(ApocalypseTheme.primary)
            Text(LocalizedString.commonLoading)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - My Channels View

    private var myChannelsView: some View {
        Group {
            if communicationManager.subscribedChannels.isEmpty {
                emptyMyChannelsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                            ChannelRowView(
                                channel: subscribedChannel.channel,
                                isSubscribed: true
                            ) {
                                selectedChannel = subscribedChannel.channel
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyMyChannelsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(LocalizedString.noSubscribedChannels)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(LocalizedString.subscribeChannelsHint)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Button(action: { showCreateSheet = true }) {
                Text(LocalizedString.createChannel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Discover Channels View

    private var discoverChannelsView: some View {
        Group {
            let filteredChannels = filterChannels(communicationManager.channels)
            if filteredChannels.isEmpty {
                emptyDiscoverView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            ) {
                                selectedChannel = channel
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyDiscoverView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            Text(LocalizedString.noChannels)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(LocalizedString.createFirstChannelHint)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }

        if selectedTab == 0 {
            await communicationManager.loadSubscribedChannels(userId: userId)
        } else {
            await communicationManager.loadPublicChannels()
            await communicationManager.loadSubscribedChannels(userId: userId)
        }
    }

    private func filterChannels(_ channels: [CommunicationChannel]) -> [CommunicationChannel] {
        guard !searchText.isEmpty else { return channels }
        return channels.filter { channel in
            channel.name.localizedCaseInsensitiveContains(searchText) ||
            channel.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(channel.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        if isSubscribed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(channel.channelType.displayName)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text("\(channel.memberCount)")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        +
                        Text(" ")
                        +
                        Text(LocalizedString.memberCount)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                // 频道码
                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
}
