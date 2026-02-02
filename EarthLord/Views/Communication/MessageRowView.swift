//
//  MessageRowView.swift
//  EarthLord
//
//  消息行组件 - Day 36 实现
//  用于消息中心显示频道摘要
//

import SwiftUI

struct MessageRowView: View {
    let summary: CommunicationManager.ChannelSummary

    private var isOfficial: Bool {
        summary.channel.channelType == .official
    }

    var body: some View {
        HStack(spacing: 12) {
            // Channel icon
            channelIcon

            // Channel info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if isOfficial {
                        Text(LocalizedString.officialBadge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }

                    Spacer()

                    // Timestamp
                    if let lastMessage = summary.lastMessage {
                        Text(lastMessage.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }

                // Latest message preview - Day 36: Always show callsign with fallback
                HStack {
                    if let lastMessage = summary.lastMessage {
                        Text("\(lastMessage.formattedCallsign): ")
                            .font(.subheadline)
                            .foregroundColor(lastMessage.hasRegisteredCallsign ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(LocalizedString.messageEmpty)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Unread count badge
                    if summary.unreadCount > 0 {
                        Text("\(summary.unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(ApocalypseTheme.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(12)
        .background(isOfficial ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Channel Icon

    private var channelIcon: some View {
        ZStack {
            Circle()
                .fill(channelIconColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: channelIconName)
                .font(.system(size: 22))
                .foregroundColor(channelIconColor)
        }
    }

    private var channelIconName: String {
        switch summary.channel.channelType {
        case .official: return "megaphone.fill"
        case .publicChannel: return "antenna.radiowaves.left.and.right"
        case .walkie: return "flipphone"
        case .camp: return "tent.fill"
        case .satellite: return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }

    private var channelIconColor: Color {
        switch summary.channel.channelType {
        case .official: return .red
        case .publicChannel: return .blue
        case .walkie: return ApocalypseTheme.primary
        case .camp: return .purple
        case .satellite: return .cyan
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        Text("MessageRowView requires ChannelSummary data")
            .foregroundColor(ApocalypseTheme.textSecondary)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
