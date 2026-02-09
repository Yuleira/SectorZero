//
//  DeviceManagementView.swift
//  EarthLord
//
//  设备管理页面
//  管理和切换通讯设备，支持资源解锁与 AEC 即时解锁
//

import SwiftUI
import Supabase

struct DeviceManagementView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var communicationManager: CommunicationManager
    @ObservedObject private var inventoryManager = InventoryManager.shared
    @State private var expandedDevice: DeviceType?
    @State private var showingCallsignSettings = false
    @State private var isUpgrading = false
    @State private var upgradeResultMessage: String?
    @State private var showUpgradeResult = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString.deviceManagement)
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(LocalizedString.selectCommunicationDevice)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Current device card
                if let current = communicationManager.currentDevice {
                    currentDeviceCard(current)
                }

                // Device list
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.allDevices)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(DeviceType.allCases, id: \.self) { deviceType in
                        deviceCard(deviceType)
                    }
                }

                // Callsign settings
                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.3))
                    .padding(.vertical, 8)

                callsignSettingsEntry
            }
            .padding(16)
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showingCallsignSettings) {
            CallsignSettingsSheet()
        }
        .alert(LocalizedString.upgradeRequirements, isPresented: $showUpgradeResult) {
            Button(LocalizedString.confirm, role: .cancel) {}
        } message: {
            if let msg = upgradeResultMessage { Text(msg) }
        }
    }

    // MARK: - Current Device Card

    private func currentDeviceCard(_ device: CommunicationDevice) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: device.deviceType.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceType.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text(device.deviceType.rangeText)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                HStack(spacing: 4) {
                    Image(systemName: device.deviceType.canSend ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(device.deviceType.canSend ? LocalizedString.canSend : LocalizedString.receiveOnly)
                        .font(.caption)
                }
                .foregroundColor(device.deviceType.canSend ? .green : .orange)
            }
            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ApocalypseTheme.primary, lineWidth: 2))
    }

    // MARK: - Device Card (Expandable)

    private func deviceCard(_ deviceType: DeviceType) -> some View {
        let device = communicationManager.devices.first(where: { $0.deviceType == deviceType })
        let isUnlocked = device?.isUnlocked ?? false
        let isCurrent = device?.isCurrent ?? false
        let isExpanded = expandedDevice == deviceType

        return VStack(spacing: 0) {
            // Header row (always visible)
            Button(action: { handleCardTap(deviceType, isUnlocked, isCurrent) }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isUnlocked ? ApocalypseTheme.primary.opacity(0.15) : ApocalypseTheme.textSecondary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Image(systemName: deviceType.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(isUnlocked ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(deviceType.displayName)
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(isUnlocked ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                            if isCurrent {
                                Text(LocalizedString.current)
                                    .font(.caption2).fontWeight(.bold).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(ApocalypseTheme.primary).cornerRadius(4)
                            }
                            if isUnlocked && !isCurrent {
                                Text(LocalizedString.upgradeUnlocked)
                                    .font(.caption2).foregroundColor(ApocalypseTheme.success)
                            }
                        }
                        Text(deviceType.description)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isUnlocked {
                        if !isCurrent {
                            Text(LocalizedString.switchDevice)
                                .font(.caption).foregroundColor(ApocalypseTheme.primary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ApocalypseTheme.primary.opacity(0.15)).cornerRadius(6)
                        }
                    } else {
                        // Expand/collapse chevron for locked devices
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(12)
            }
            .disabled(isCurrent)

            // Expandable requirements section (only for locked devices)
            if !isUnlocked && isExpanded, let reqs = deviceType.upgradeRequirements {
                requirementsPanel(deviceType: deviceType, reqs: reqs)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .opacity(isUnlocked ? 1.0 : (isExpanded ? 1.0 : 0.7))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Requirements Panel

    private func requirementsPanel(deviceType: DeviceType, reqs: DeviceUpgradeRequirements) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))

            // Prerequisite check
            if let prereq = reqs.prerequisiteDeviceId {
                let prereqMet = communicationManager.isDeviceUnlocked(prereq)
                requirementRow(
                    icon: prereq.iconName,
                    label: String(localized: LocalizedString.upgradePrerequisite),
                    detail: prereq.displayName,
                    isMet: prereqMet
                )
            }

            // Territory requirement
            let territoryCount = TerritoryManager.shared.territories.count
            let territoryMet = territoryCount >= reqs.neededTerritories
            requirementRow(
                icon: "map.fill",
                label: String(localized: LocalizedString.upgradeNeededTerritories),
                detail: String(format: String(localized: LocalizedString.upgradeTerritoriesFormat), territoryCount, reqs.neededTerritories),
                isMet: territoryMet
            )

            // Resource requirements
            Text(LocalizedString.upgradeNeededResources)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 4)

            ForEach(reqs.neededResources.sorted(by: { $0.key < $1.key }), id: \.key) { resourceId, needed in
                let have = inventoryManager.getResourceQuantity(for: resourceId)
                let isMet = have >= needed
                HStack(spacing: 8) {
                    Image(systemName: inventoryManager.resourceIconName(for: resourceId))
                        .font(.caption)
                        .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)
                        .frame(width: 20)
                    Text(inventoryManager.resourceDisplayName(for: resourceId))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(have) / \(needed)")
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)

                    Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
            }

            // Action buttons
            VStack(spacing: 8) {
                // Resource unlock button
                let checkResult = communicationManager.checkUpgradeRequirements(for: deviceType)
                let canUpgrade: Bool = {
                    if case .success = checkResult { return true }
                    return false
                }()

                Button {
                    performResourceUpgrade(deviceType)
                } label: {
                    HStack {
                        if isUpgrading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "hammer.fill")
                            Text(LocalizedString.upgradeWithResources)
                        }
                    }
                    .font(.caption).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canUpgrade ? ApocalypseTheme.success : ApocalypseTheme.textSecondary.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!canUpgrade || isUpgrading)

            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Requirement Row

    private func requirementRow(icon: String, label: String, detail: String, isMet: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(detail)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(isMet ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
    }

    // MARK: - Actions

    private func handleCardTap(_ deviceType: DeviceType, _ isUnlocked: Bool, _ isCurrent: Bool) {
        if isCurrent { return }

        if !isUnlocked {
            // Toggle expand/collapse
            withAnimation {
                expandedDevice = expandedDevice == deviceType ? nil : deviceType
            }
            return
        }

        // Switch to unlocked device
        guard let userId = authManager.currentUser?.id else { return }
        Task { await communicationManager.switchDevice(userId: userId, to: deviceType) }
    }

    private func performResourceUpgrade(_ deviceType: DeviceType) {
        guard let userId = authManager.currentUser?.id else { return }
        isUpgrading = true
        Task {
            let result = await communicationManager.attemptUpgrade(userId: userId, deviceType: deviceType)
            isUpgrading = false

            switch result {
            case .success:
                upgradeResultMessage = String(localized: LocalizedString.upgradeSuccess)
                expandedDevice = nil
            case .missingPrerequisite(let prereq):
                upgradeResultMessage = String(localized: LocalizedString.upgradePrerequisiteRequired) + " (\(prereq.displayName))"
            case .insufficientTerritories(let have, let need):
                upgradeResultMessage = String(format: String(localized: LocalizedString.upgradeTerritoriesFormat), have, need)
            case .insufficientResources:
                upgradeResultMessage = String(localized: LocalizedString.upgradeInsufficientResources)
            case .alreadyUnlocked:
                upgradeResultMessage = String(localized: LocalizedString.upgradeUnlocked)
            case .noRequirements:
                upgradeResultMessage = nil
            }

            if upgradeResultMessage != nil {
                showUpgradeResult = true
            }
        }
    }


    // MARK: - Callsign Settings Entry

    private var callsignSettingsEntry: some View {
        Button(action: {
            showingCallsignSettings = true
        }) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedString.callsignSettings)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(LocalizedString.notSet)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        DeviceManagementView(authManager: AuthManager.shared, communicationManager: CommunicationManager.shared)
    }
}
