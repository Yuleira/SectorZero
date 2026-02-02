//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页 - Day 36 完整实现
//  支持消息分类过滤和官方公告展示
//

import SwiftUI

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @ObservedObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = true

    private var messages: [ChannelMessage] {
        let allMessages = communicationManager.getMessages(for: channel.id)
        if let category = selectedCategory {
            return allMessages.filter { $0.category == category }
        }
        return allMessages
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                // Category filter
                categoryFilter

                // Message list
                messageListView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMessages()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(.red)
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(LocalizedString.officialAnnouncement)
                    Text("·")
                    Text(LocalizedString.globalCoverage)
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All category
                CategoryChip(
                    title: String(localized: LocalizedString.categoryAll),
                    icon: "list.bullet",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // Individual categories
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .padding(.top, 50)
            } else if messages.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        OfficialMessageBubble(message: message)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))

            if let category = selectedCategory {
                Text(String(format: String(localized: LocalizedString.noCategoryMessagesFormat), category.displayName))
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(LocalizedString.noAnnouncements)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func loadMessages() {
        isLoading = true
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - Official Message Bubble

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category badge
            if let category = message.category {
                HStack(spacing: 4) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 12))
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .foregroundColor(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.color.opacity(0.15))
                .cornerRadius(8)
            }

            // Message content
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // Timestamp
            Text(message.timeAgo)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.category?.color.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    // Preview requires a mock channel - this won't work without actual data
    // Use NavigationStack in the actual app
    Text("OfficialChannelDetailView Preview")
}
