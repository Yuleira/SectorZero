//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道表单
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var communicationManager = CommunicationManager.shared

    @State private var selectedType: ChannelType = .publicChannel
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    typeSelectionSection

                    // 名称输入
                    nameInputSection

                    // 描述输入
                    descriptionInputSection

                    // 创建按钮
                    createButton
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(Text(LocalizedString.createChannel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text(LocalizedString.commonCancel)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Type Selection Section

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedString.selectChannelType)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ChannelType.userCreatableTypes, id: \.rawValue) { type in
                    ChannelTypeCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    }
                }
            }
        }
    }

    // MARK: - Name Input Section

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedString.channelName)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            TextField(String(localized: LocalizedString.channelName), text: $channelName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 验证提示
            if !channelName.isEmpty {
                let validation = nameValidation
                HStack {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(validation.isValid ? .green : .orange)
                        .font(.caption)

                    Text(validation.message)
                        .font(.caption)
                        .foregroundColor(validation.isValid ? .green : .orange)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            } else {
                Text(LocalizedString.channelNameLengthHint)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Description Input Section

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedString.channelDescription)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            TextEditor(text: $channelDescription)
                .frame(minHeight: 80)
                .padding(8)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: createChannel) {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)

                    Text(LocalizedString.creatingChannel)
                        .font(.headline)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else {
                    Text(LocalizedString.createChannel)
                        .font(.headline)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
        .padding(.top, 8)
    }

    // MARK: - Validation

    private var nameValidation: (isValid: Bool, message: LocalizedStringResource) {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            return (false, LocalizedString.channelNameTooShort)
        }
        if trimmed.count > 50 {
            return (false, LocalizedString.channelNameTooLong)
        }
        return (true, LocalizedString.channelNameLengthHint)
    }

    private var canCreate: Bool {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 50
    }

    // MARK: - Actions

    private func createChannel() {
        guard let userId = authManager.currentUser?.id else { return }

        isCreating = true

        Task {
            let trimmedName = channelName.trimmingCharacters(in: .whitespaces)
            let trimmedDesc = channelDescription.trimmingCharacters(in: .whitespaces)

            let _ = await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc
            )

            await MainActor.run {
                isCreating = false
                if communicationManager.errorMessage == nil {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Channel Type Card

struct ChannelTypeCard: View {
    let type: ChannelType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? ApocalypseTheme.primary.opacity(0.2) : ApocalypseTheme.cardBackground)
                        .frame(width: 50, height: 50)

                    Image(systemName: type.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                }

                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ApocalypseTheme.primary.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager.shared)
}
