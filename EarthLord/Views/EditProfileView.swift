//
//  EditProfileView.swift
//  EarthLord
//
//  编辑个人资料页面
//  允许用户修改用户名
//

import SwiftUI
import Supabase

/// 编辑个人资料视图
struct EditProfileView: View {

    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                ZStack {
                    Circle()
                        .stroke(ApocalypseTheme.primary, lineWidth: 3)
                        .frame(width: 106, height: 106)

                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.8))
                        .frame(width: 100, height: 100)

                    Image(systemName: "person.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)

                // Email (read-only)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(authManager.currentUser?.email ?? "-")
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(ApocalypseTheme.cardBackground.opacity(0.5))
                        .cornerRadius(12)
                }

                // Username (editable)
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString.profileEditProfile)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("", text: $username)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(14)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Save button
                Button {
                    saveProfile()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 4)
                        }
                        Text(LocalizedString.commonSave)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(username.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : ApocalypseTheme.primary)
                    )
                }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle(Text(LocalizedString.profileEditProfile))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            // Pre-fill current username
            if let name = authManager.currentUser?.userMetadata["username"]?.stringValue, !name.isEmpty {
                username = name
            } else if let email = authManager.currentUser?.email,
                      let prefix = email.split(separator: "@").first {
                username = String(prefix)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if showSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(LocalizedString.commonSave)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.green))
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
    }

    private func saveProfile() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        Task {
            do {
                try await authManager.updateUsername(trimmed)
                isSaving = false
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSuccess = false
                    dismiss()
                }
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
