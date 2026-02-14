//
//  PrivacyPolicyView.swift
//  EarthLord
//
//  Native privacy policy view styled with ApocalypseTheme.
//  All text is localized via the LocalizedString system (EN + ZH-Hans).
//

import SwiftUI

// MARK: - View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString.privacyTitle)
                        .font(.title2.bold())
                        .foregroundColor(ApocalypseTheme.primary)
                    Text(LocalizedString.privacyLastUpdated)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(16)

                // Section 1: Introduction
                sectionCard {
                    sectionTitle(LocalizedString.privacyS1Title)
                    bodyText(LocalizedString.privacyS1P1)
                    bodyText(LocalizedString.privacyS1P2)
                    bodyText(LocalizedString.privacyS1P3)
                    bodyText(LocalizedString.privacyS1P4)
                }

                // Section 2: Information We Collect
                sectionCard {
                    sectionTitle(LocalizedString.privacyS2Title)

                    // 2.1 Personal & Account Data
                    subSectionTitle(LocalizedString.privacyS2_1Title)
                    bodyText(LocalizedString.privacyS2_1Intro)
                    bulletItem(LocalizedString.privacyS2_1B1)
                    bulletItem(LocalizedString.privacyS2_1B2)
                    bulletItem(LocalizedString.privacyS2_1B3)
                    bulletItem(LocalizedString.privacyS2_1B4)

                    sectionDivider()

                    // 2.2 Location Data
                    subSectionTitle(LocalizedString.privacyS2_2Title)
                    bodyText(LocalizedString.privacyS2_2Intro1)
                    bodyText(LocalizedString.privacyS2_2Intro2)
                    bulletItem(LocalizedString.privacyS2_2B1)
                    bulletItem(LocalizedString.privacyS2_2B2)

                    Spacer().frame(height: 8)
                    bodyText(LocalizedString.privacyS2_2NoteIntro)
                    bulletItem(LocalizedString.privacyS2_2B3)
                    bulletItem(LocalizedString.privacyS2_2B4)
                    bulletItem(LocalizedString.privacyS2_2B5)

                    sectionDivider()

                    // 2.3 Gameplay & Financial Data
                    subSectionTitle(LocalizedString.privacyS2_3Title)
                    bodyText(LocalizedString.privacyS2_3Intro)
                    bulletItem(LocalizedString.privacyS2_3B1)
                    bulletItem(LocalizedString.privacyS2_3B2)
                    bulletItem(LocalizedString.privacyS2_3B3)
                    bulletItem(LocalizedString.privacyS2_3B4)
                    noteText(LocalizedString.privacyS2_3Note)

                    sectionDivider()

                    // 2.4 Diagnostic & Technical Data
                    subSectionTitle(LocalizedString.privacyS2_4Title)
                    bodyText(LocalizedString.privacyS2_4Intro)
                    bulletItem(LocalizedString.privacyS2_4B1)
                    bulletItem(LocalizedString.privacyS2_4B2)
                    bulletItem(LocalizedString.privacyS2_4B3)
                    noteText(LocalizedString.privacyS2_4Note)
                }

                // Section 3: Legal Basis
                sectionCard {
                    sectionTitle(LocalizedString.privacyS3Title)
                    bodyText(LocalizedString.privacyS3Intro)
                    bulletItem(LocalizedString.privacyS3B1)
                    bulletItem(LocalizedString.privacyS3B2)
                    bulletItem(LocalizedString.privacyS3B3)
                    noteText(LocalizedString.privacyS3Note)
                }

                // Section 4: How We Use Your Information
                sectionCard {
                    sectionTitle(LocalizedString.privacyS4Title)
                    bodyText(LocalizedString.privacyS4Intro)
                    bulletItem(LocalizedString.privacyS4B1)
                    bulletItem(LocalizedString.privacyS4B2)
                    bulletItem(LocalizedString.privacyS4B3)
                    bulletItem(LocalizedString.privacyS4B4)
                    bulletItem(LocalizedString.privacyS4B5)
                    noteText(LocalizedString.privacyS4Note)
                }

                // Section 5: Data Storage
                sectionCard {
                    sectionTitle(LocalizedString.privacyS5Title)
                    bodyText(LocalizedString.privacyS5P1)
                    bodyText(LocalizedString.privacyS5P2)
                    bodyText(LocalizedString.privacyS5P3)
                }

                // Section 6: Data Retention
                sectionCard {
                    sectionTitle(LocalizedString.privacyS6Title)
                    bodyText(LocalizedString.privacyS6Intro)
                    bulletItem(LocalizedString.privacyS6B1)
                    bulletItem(LocalizedString.privacyS6B2)
                }

                // Section 7: Data Sharing & Third Parties
                sectionCard {
                    sectionTitle(LocalizedString.privacyS7Title)
                    bodyText(LocalizedString.privacyS7P1)
                    bodyText(LocalizedString.privacyS7P2)
                    thirdPartyItem(
                        name: LocalizedString.privacyS7B1,
                        url: "https://supabase.com/privacy"
                    )
                    thirdPartyItem(
                        name: LocalizedString.privacyS7B2,
                        url: "https://www.apple.com/legal/privacy/"
                    )
                    noteText(LocalizedString.privacyS7Note)
                }

                // Section 8: Your Rights
                sectionCard {
                    sectionTitle(LocalizedString.privacyS8Title)
                    bodyText(LocalizedString.privacyS8Intro)
                    bulletItem(LocalizedString.privacyS8B1)
                    bulletItem(LocalizedString.privacyS8B2)
                    bulletItem(LocalizedString.privacyS8B3)
                    bulletItem(LocalizedString.privacyS8B4)
                    bulletItem(LocalizedString.privacyS8B5)
                    Spacer().frame(height: 4)
                    bodyText(LocalizedString.privacyS8DeleteVia)
                    bodyText(LocalizedString.privacyS8DeletePath)
                    noteText(LocalizedString.privacyS8Irreversible)
                    noteText(LocalizedString.privacyS8Contact)
                }

                // Section 9: Children's Privacy
                sectionCard {
                    sectionTitle(LocalizedString.privacyS9Title)
                    bodyText(LocalizedString.privacyS9P1)
                    bodyText(LocalizedString.privacyS9P2)
                    bodyText(LocalizedString.privacyS9P3)
                }

                // Section 10: Changes to This Policy
                sectionCard {
                    sectionTitle(LocalizedString.privacyS10Title)
                    bodyText(LocalizedString.privacyS10P1)
                    bodyText(LocalizedString.privacyS10P2)
                    bodyText(LocalizedString.privacyS10P3)
                }

                // Section 11: Contact
                sectionCard {
                    sectionTitle(LocalizedString.privacyS11Title)
                    bodyText(LocalizedString.privacyS11Intro)

                    Spacer().frame(height: 4)
                    Text(LocalizedString.privacyS11Name)
                        .font(.subheadline.bold())
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("rachelyulei+sectorzero@gmail.com")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.info)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(ApocalypseTheme.background.ignoresSafeArea())
        .navigationTitle(Text(LocalizedString.profilePrivacyPolicy))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Card Container

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Text Components

    private func sectionTitle(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.headline)
            .foregroundColor(ApocalypseTheme.primary)
    }

    private func subSectionTitle(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.subheadline.bold())
            .foregroundColor(ApocalypseTheme.textPrimary)
            .padding(.top, 4)
    }

    private func bodyText(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func noteText(_ key: LocalizedStringResource) -> some View {
        Text(key)
            .font(.subheadline)
            .foregroundColor(ApocalypseTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bulletItem(_ key: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(ApocalypseTheme.primary)
            Text(key)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 8)
    }

    private func thirdPartyItem(name: LocalizedStringResource, url: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(ApocalypseTheme.primary)
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(url)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.info)
                .padding(.leading, 16)
        }
        .padding(.leading, 8)
    }

    private func sectionDivider() -> some View {
        Divider()
            .background(ApocalypseTheme.textMuted.opacity(0.3))
            .padding(.vertical, 4)
    }
}
