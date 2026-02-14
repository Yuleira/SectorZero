//
//  ProfileSettingsView.swift
//  EarthLord
//
//  Settings list extracted from ProfileTabView.
//

import SwiftUI
import SafariServices
import MessageUI
internal import Auth

/// 设置页面
/// 包含语言、技术支持、隐私政策、退出登录、删除账号
struct ProfileSettingsView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showDeleteAccountSheet = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showOnboarding = false
    @State private var showPrivacyPolicy = false
    @State private var showTechSupportMail = false

    @Environment(\.openURL) private var openURL

    private var techSupportMailSubject: String {
        let userEmail = authManager.currentUser?.email ?? "unknown"
        return "[SectorZero Support] Feedback from \(userEmail)"
    }

    private var techSupportMailBody: String {
        """
        Please describe your issue below:

        ---
        Device: \(UIDevice.current.model)
        OS: \(UIDevice.current.systemVersion)
        """
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - 设置列表
                VStack(spacing: 0) {
                    // 编辑资料
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        settingsRow(
                            icon: "pencil",
                            title: LocalizedString.profileEditProfile,
                            trailingText: nil
                        )
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 语言
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        settingsRow(
                            icon: "globe",
                            title: LocalizedString.profileLanguage,
                            trailingText: languageManager.selectedLanguage.displayName
                        )
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 技术支持
                    Button {
                        openTechSupportMail()
                    } label: {
                        settingsRow(
                            icon: "questionmark.circle.fill",
                            title: LocalizedString.profileTechSupport,
                            trailingText: nil
                        )
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 隐私政策
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        settingsRow(
                            icon: "hand.raised.fill",
                            title: LocalizedString.profilePrivacyPolicy,
                            trailingText: nil
                        )
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 操作手册 (re-watch onboarding)
                    Button {
                        showOnboarding = true
                    } label: {
                        settingsRow(
                            icon: "book.fill",
                            title: LocalizedString.onboardingManual,
                            trailingText: nil
                        )
                    }
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)

                // MARK: - 账号操作
                VStack(spacing: 12) {
                    // 退出登录
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(ApocalypseTheme.danger)
                            Text(LocalizedString.profileLogout)
                                .foregroundColor(ApocalypseTheme.danger)
                            Spacer()
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }
                    .disabled(isLoggingOut)

                    // 删除账号
                    Button {
                        showDeleteAccountSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(LocalizedString.profileDeleteAccount)
                                .foregroundColor(ApocalypseTheme.danger)
                            Spacer()
                        }
                        .padding(16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }

                    // 警告文字
                    Text(LocalizedString.profileDeleteAccountWarning)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle(Text(LocalizedString.profileSettings))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .id(languageManager.refreshID)
        .alert(LocalizedString.profileLogoutConfirmTitle, isPresented: $showLogoutAlert) {
            Button(LocalizedString.commonCancel, role: .cancel) { }
            Button(LocalizedString.profileLogoutAction, role: .destructive) {
                performLogout()
            }
        } message: {
            Text(LocalizedString.profileLogoutConfirmMessage)
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            DeleteAccountConfirmView(
                isPresented: $showDeleteAccountSheet,
                onError: { error in
                    deleteErrorMessage = error
                    showDeleteError = true
                }
            )
        }
        .alert(LocalizedString.profileDeleteFailed, isPresented: $showDeleteError) {
            Button(LocalizedString.commonOk, role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: URL(string: "https://gist.github.com/Yuleira/893972104f2ece0a07ebd8b60f3dbdca")!)
        }
        .sheet(isPresented: $showTechSupportMail) {
            MailComposeView(
                recipients: ["support@sectorzero.app"],
                subject: techSupportMailSubject,
                body: techSupportMailBody,
                isPresented: $showTechSupportMail
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - 设置行辅助
    private func settingsRow(icon: String, title: LocalizedStringResource, trailingText: LocalizedStringResource?) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            if let trailingText = trailingText {
                Text(trailingText)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(16)
    }

    // MARK: - 方法

    /// 打开技术支持邮件：优先使用系统邮件组件，不可用时回退到 mailto
    private func openTechSupportMail() {
        if MFMailComposeViewController.canSendMail() {
            showTechSupportMail = true
        } else if let url = techSupportMailtoURL {
            openURL(url)
        }
    }

    /// 构建 mailto URL（当设备未配置邮件时回退使用）
    private var techSupportMailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@sectorzero.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: techSupportMailSubject),
            URLQueryItem(name: "body", value: techSupportMailBody)
        ]
        return components.url
    }

    /// 执行退出登录
    private func performLogout() {
        isLoggingOut = true
        Task {
            await authManager.signOut()
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            isPresented = false
        }
    }
}
