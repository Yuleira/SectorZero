//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情页面
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    let channel: CommunicationChannel

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager
    @ObservedObject var communicationManager: CommunicationManager

    @State private var showDeleteConfirm = false
    @State private var isProcessing = false

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头像和基本信息
                    headerSection

                    // 订阅状态
                    if isSubscribed {
                        subscribedBadge
                    }

                    // 频道介绍
                    if let description = channel.description, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // 频道信息卡片
                    infoCard

                    // 操作按钮
                    actionButtons

                    Spacer()
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(Text(LocalizedString.channelDetails))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert(String(localized: LocalizedString.confirmDelete), isPresented: $showDeleteConfirm) {
                Button(String(localized: LocalizedString.commonCancel), role: .cancel) {}
                Button(String(localized: LocalizedString.deleteChannel), role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text(LocalizedString.deleteChannelConfirmMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道名称
            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // 频道码
            HStack(spacing: 4) {
                Text(LocalizedString.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(channel.channelCode)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Subscribed Badge

    private var subscribedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)

            Text(LocalizedString.subscribed)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(20)
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedString.channelDescription)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            Text(LocalizedString.channelInfo)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 频道类型
            infoRow(
                icon: "antenna.radiowaves.left.and.right",
                title: LocalizedString.channelType,
                value: channel.channelType.displayName
            )

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 成员数量
            infoRow(
                icon: "person.2.fill",
                title: LocalizedString.memberCount,
                value: "\(channel.memberCount)"
            )

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.2))

            // 创建时间
            infoRow(
                icon: "calendar",
                title: LocalizedString.createdAt,
                value: formatDate(channel.createdAt)
            )

            // 显示创建者标识
            if isCreator {
                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.2))

                infoRow(
                    icon: "star.fill",
                    title: LocalizedString.channelCreator,
                    value: ""
                )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, title: LocalizedStringResource, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCreator {
                // 创建者：删除按钮
                Button(action: { showDeleteConfirm = true }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Image(systemName: "trash.fill")
                        Text(LocalizedString.deleteChannel)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            } else {
                // 非创建者：订阅/取消订阅按钮
                if isSubscribed {
                    Button(action: unsubscribe) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "bell.slash.fill")
                            Text(LocalizedString.unsubscribe)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.textSecondary)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                } else {
                    Button(action: subscribe) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "bell.fill")
                            Text(LocalizedString.subscribe)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func subscribe() {
        isProcessing = true
        Task {
            await communicationManager.subscribeToChannel(channelId: channel.id)
            if let userId = authManager.currentUser?.id {
                await communicationManager.loadSubscribedChannels(userId: userId)
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func unsubscribe() {
        isProcessing = true
        Task {
            await communicationManager.unsubscribeFromChannel(channelId: channel.id)
            if let userId = authManager.currentUser?.id {
                await communicationManager.loadSubscribedChannels(userId: userId)
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func deleteChannel() {
        isProcessing = true
        Task {
            let didDelete = await communicationManager.deleteChannel(channelId: channel.id)
            await MainActor.run {
                isProcessing = false
                if didDelete && communicationManager.errorMessage == nil {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    ChannelDetailView(
        channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .publicChannel,
            channelCode: "PUB-ABC123",
            name: "Test Channel",
            description: "This is a test channel for preview purposes.",
            isActive: true,
            memberCount: 42,
            createdAt: Date(),
            updatedAt: Date()
        ),
        authManager: AuthManager.shared,
        communicationManager: CommunicationManager.shared
    )
}
