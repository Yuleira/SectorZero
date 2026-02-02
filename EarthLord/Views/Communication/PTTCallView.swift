//
//  PTTCallView.swift
//  EarthLord
//
//  PTT呼叫页面 - Day 36 完整实现
//  支持长按发送消息的对讲机体验
//  Enhanced: Pulse animation, haptic feedback, radio static sound
//

import SwiftUI
internal import Auth
import CoreLocation
import AVFoundation

struct PTTCallView: View {
    @ObservedObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var selectedChannelId: UUID?
    @State private var messageContent: String = ""
    @State private var isPressingPTT: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var signalPulse: Bool = false

    // Keyboard focus state
    @FocusState private var isInputFocused: Bool

    // Audio player for radio static
    @State private var audioPlayer: AVAudioPlayer?

    private var subscribedChannels: [SubscribedChannel] {
        communicationManager.subscribedChannels.filter {
            // Exclude official channel (official channel is receive-only)
            !communicationManager.isOfficialChannel($0.channel.id)
        }
    }

    private var selectedChannel: CommunicationChannel? {
        subscribedChannels.first { $0.channel.id == selectedChannelId }?.channel
    }

    private var canSend: Bool {
        communicationManager.canSendMessage() &&
        selectedChannel != nil &&
        !messageContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if current device is Radio (receive-only)
    private var isRadioMode: Bool {
        communicationManager.getCurrentDeviceType() == .radio
    }

    var body: some View {
        ZStack {
            // Background with tap-to-dismiss keyboard
            ApocalypseTheme.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header (always visible)
                    headerView

                    // Radio mode warning banner
                    if isRadioMode {
                        radioModeWarning
                    }

                    // Current frequency card (adaptive: compact when typing)
                    if let channel = selectedChannel {
                        if isInputFocused {
                            compactFrequencyCard(channel: channel)
                        } else {
                            frequencyCard(channel: channel)
                        }
                    }

                    // Channel selector tabs (hidden when typing for more space)
                    if !isInputFocused {
                        channelTabBar
                    }

                    Spacer(minLength: isInputFocused ? 8 : 16)

                    // Message input area (disabled in radio mode)
                    messageInputArea
                        .opacity(isRadioMode ? 0.5 : 1.0)
                        .disabled(isRadioMode)

                    // PTT button with pulse animation
                    pttButtonWithPulse
                        .padding(.vertical, isInputFocused ? 12 : 16)

                    // Hint text
                    if !isInputFocused {
                        Text(isRadioMode ? LocalizedString.receiveOnly : LocalizedString.holdToCallHint)
                            .font(.caption)
                            .foregroundColor(isRadioMode ? .orange : ApocalypseTheme.textSecondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.bottom, 20)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isInputFocused)
            }
        }
        .onAppear {
            if selectedChannelId == nil {
                selectedChannelId = subscribedChannels.first?.channel.id
            }
            prepareRadioStaticSound()
        }
        .overlay(successToast)
    }

    // MARK: - Keyboard Dismiss Helper

    private func dismissKeyboard() {
        isInputFocused = false
    }

    // MARK: - Radio Mode Warning

    private var radioModeWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(LocalizedString.messageRadioModeHint)
                .font(.subheadline)
                .foregroundColor(.orange)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text(LocalizedString.pttCallTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer()

            // Current device indicator
            HStack(spacing: 4) {
                Image(systemName: communicationManager.getCurrentDeviceType().iconName)
                Text(communicationManager.getCurrentDeviceType().displayName)
                    .font(.caption)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.primary.opacity(0.15))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Frequency Card (Tactical Radio Dashboard)

    private func frequencyCard(channel: CommunicationChannel) -> some View {
        VStack(spacing: 12) {
            // Top row: Antenna icon + Signal status + Range indicator
            HStack {
                // Antenna with signal pulse
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)

                    // Active signal indicator (pulsing green dot)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.8), radius: signalPulse ? 6 : 2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: signalPulse)
                        .onAppear { signalPulse = true }

                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                Spacer()

                // Range indicator badge
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.right")
                        .font(.caption2)
                    Text(communicationManager.getCurrentDeviceType().rangeText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.background.opacity(0.5))
                .cornerRadius(6)
            }

            // Primary: Channel Name (large, bold)
            Text(channel.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            // Secondary: Channel code with appropriate unit based on type
            channelCodeDisplay(for: channel)

            // Signal strength bars (visual flair)
            signalStrengthBars
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Compact Frequency Card (Keyboard Active Mode)

    private func compactFrequencyCard(channel: CommunicationChannel) -> some View {
        HStack(spacing: 12) {
            // Antenna with signal pulse (smaller)
            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green.opacity(0.6), radius: signalPulse ? 4 : 1)
            }

            // Channel Name (compact)
            Text(channel.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Frequency code only (no MHz label in compact mode)
            Text(channel.channelCode)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.primary.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // Intelligent channel code display based on channel type
    @ViewBuilder
    private func channelCodeDisplay(for channel: CommunicationChannel) -> some View {
        HStack(spacing: 4) {
            // Walkie channels use MHz frequency format (438.xxx)
            if channel.channelType == .walkie {
                Text(channel.channelCode)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("MHz")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                // Other channels show code as tactical ID
                Text("ID:")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(channel.channelCode)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .minimumScaleFactor(0.5)
    }

    // Signal strength bars indicator
    private var signalStrengthBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < 4 ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.3))
                    .frame(width: 6, height: CGFloat(8 + index * 3))
            }
        }
        .frame(height: 20, alignment: .bottom)
    }

    // MARK: - Channel Tab Bar (Name-First Design)

    private var channelTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(subscribedChannels) { subscribedChannel in
                    let channel = subscribedChannel.channel
                    let isSelected = channel.id == selectedChannelId

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedChannelId = channel.id
                        }
                    }) {
                        VStack(spacing: 2) {
                            // Primary: Channel Name
                            Text(channel.name)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            // Secondary: Frequency (only visible when selected)
                            if isSelected {
                                Text(channel.channelCode)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, isSelected ? 10 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Message Input Area

    private var messageInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label (hidden when focused for more space)
            if !isInputFocused {
                Text(LocalizedString.callContent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $messageContent)
                    .frame(height: isInputFocused ? 60 : 80)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .focused($isInputFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: LocalizedString.commonDone)) {
                                dismissKeyboard()
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(ApocalypseTheme.primary)
                        }
                    }

                if messageContent.isEmpty {
                    Text(LocalizedString.callContentPlaceholder)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                // Border highlight when focused
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isInputFocused ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, isInputFocused ? 8 : 20)
    }

    // MARK: - PTT Button with Pulse Animation

    // Button size adapts to keyboard state
    private var pttButtonSize: CGFloat {
        isInputFocused ? 100 : 120
    }

    private var pttButtonWithPulse: some View {
        ZStack {
            // Pulse rings (breathing light effect) - only when not typing
            if isPressingPTT && !isInputFocused {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(ApocalypseTheme.primary.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: pttButtonSize + CGFloat(index) * 20, height: pttButtonSize + CGFloat(index) * 20)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - pulseScale)
                }
            }

            // Main PTT button
            pttButton
        }
        .onChange(of: isPressingPTT) { _, pressing in
            if pressing {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }

    private var pttButton: some View {
        Button(action: {}) {
            VStack(spacing: isInputFocused ? 4 : 8) {
                Image(systemName: isPressingPTT ? "waveform" : "mic.fill")
                    .font(.system(size: isInputFocused ? 28 : 36))
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPressingPTT)

                Text(isPressingPTT ? LocalizedString.sending : LocalizedString.pressToSend)
                    .font(isInputFocused ? .subheadline : .headline)
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(width: pttButtonSize, height: pttButtonSize)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isPressingPTT
                                ? [Color.red, Color.red.opacity(0.7)]
                                : (canSend
                                    ? [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)]
                                    : [Color.gray, Color.gray.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: isPressingPTT ? Color.red.opacity(0.6) : ApocalypseTheme.primary.opacity(0.5), radius: isPressingPTT ? 20 : 10)
            .scaleEffect(isPressingPTT ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressingPTT)
        }
        .disabled(!canSend)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard canSend && !isPressingPTT else { return }
                    // Auto-dismiss keyboard when pressing PTT
                    if isInputFocused {
                        dismissKeyboard()
                    }
                    isPressingPTT = true
                    triggerPressHaptic()
                }
                .onEnded { _ in
                    if isPressingPTT {
                        isPressingPTT = false
                        sendPTTMessage()
                    }
                }
        )
    }

    // MARK: - Success Toast

    private var successToast: some View {
        Group {
            if showingSuccess {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(LocalizedString.messageSent)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(20)
                    .shadow(radius: 10)

                    Spacer().frame(height: 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Haptic Feedback Methods

    private func triggerPressHaptic() {
        // Medium impact on press
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func triggerReleaseHaptic() {
        // Success notification on release
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.3
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            pulseScale = 1.0
        }
    }

    // MARK: - Radio Static Sound

    private func prepareRadioStaticSound() {
        // Try to load a custom sound file, or use system sound as fallback
        if let soundURL = Bundle.main.url(forResource: "radio_static", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 0.3
            } catch {
                print("⚠️ [PTT] Could not load radio static sound: \(error)")
            }
        }
    }

    private func playRadioStatic() {
        // Play custom sound if available
        if let player = audioPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback: Use system haptic as "click" feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    // MARK: - Send Message

    private func sendPTTMessage() {
        guard let channelId = selectedChannelId,
              !messageContent.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let content = messageContent

        // Play radio static "krrrch" effect
        playRadioStatic()

        // Get current location for distance filtering
        let location = LocationManager.shared.userLocation

        Task {
            let success = await communicationManager.sendChannelMessage(
                channelId: channelId,
                content: content,
                latitude: location?.latitude,
                longitude: location?.longitude,
                deviceType: communicationManager.getCurrentDeviceType().rawValue
            )

            if success {
                await MainActor.run {
                    messageContent = ""

                    // Success haptic
                    triggerReleaseHaptic()

                    withAnimation {
                        showingSuccess = true
                    }

                    // Hide success toast after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSuccess = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PTTCallView()
}
