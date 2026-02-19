//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  呼号设置弹窗 - Day 36 实现
//  允许用户设置和修改呼号
//

import SwiftUI
internal import Auth
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var callsign: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    private let client = SupabaseService.shared.client

    private var isValid: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Info section
                    infoSection

                    // Input section
                    inputSection

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                    }

                    // Save button
                    saveButton

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(String(localized: LocalizedString.callsignSettings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: LocalizedString.commonCancel)) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear {
            loadCurrentCallsign()
        }
        .alert(String(localized: LocalizedString.callsignSaved), isPresented: $showingSuccess) {
            Button(String(localized: LocalizedString.commonOk)) {
                dismiss()
            }
        } message: {
            Text(String(format: String(localized: LocalizedString.callsignUpdatedFormat), callsign))
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text(LocalizedString.whatIsCallsign)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Text(LocalizedString.callsignExplanation)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .minimumScaleFactor(0.5)
                .lineLimit(4)

            // Format examples
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedString.recommendedFormat)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    ForEach(["BJ-Alpha-001", "SH-Beta-42", "Survivor-X"], id: \.self) { example in
                        Text(example)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(4)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedString.yourCallsign)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            TextField(String(localized: LocalizedString.callsignPlaceholder), text: $callsign)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isValid ? ApocalypseTheme.primary : Color.gray, lineWidth: 1)
                )
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            Text(LocalizedString.callsignFormatHint)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveCallsign) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text(LocalizedString.saveCallsign)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isValid ? ApocalypseTheme.primary : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!isValid || isLoading)
    }

    // MARK: - Methods

    private func loadCurrentCallsign() {
        guard let userId = authManager.currentUser?.id else { return }

        Task {
            do {
                struct UserProfile: Decodable {
                    let callsign: String?
                }

                let profiles: [UserProfile] = try await client
                    .from("player_profiles")
                    .select("callsign")
                    .eq("user_id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if let profile = profiles.first, let existingCallsign = profile.callsign {
                    await MainActor.run {
                        callsign = existingCallsign
                    }
                }
            } catch {
                debugLog("❌ [呼号] 加载失败: \(error)")
            }
        }
    }

    private func saveCallsign() {
        guard isValid else { return }

        // Validate format: only letters, numbers, hyphens
        let pattern = "^[A-Za-z0-9-]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(callsign.startIndex..., in: callsign)

        if regex?.firstMatch(in: callsign, range: range) == nil {
            errorMessage = String(localized: LocalizedString.callsignInvalidFormat)
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let userId = authManager.currentUser?.id else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
                }

                // Upsert callsign to player_profiles
                struct UpsertData: Encodable {
                    let user_id: String
                    let callsign: String
                }

                let data = UpsertData(user_id: userId.uuidString, callsign: callsign)

                try await client
                    .from("player_profiles")
                    .upsert(data, onConflict: "user_id")
                    .execute()

                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                    debugLog("✅ [呼号] 保存成功: \(callsign)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    debugLog("❌ [呼号] 保存失败: \(error)")
                }
            }
        }
    }
}

#Preview {
    CallsignSettingsSheet()
}
