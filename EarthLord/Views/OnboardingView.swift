//
//  OnboardingView.swift
//  EarthLord
//
//  Tactical Initiation Protocol — Immersive onboarding experience
//  Full-screen paged walkthrough for first-run users
//

import SwiftUI

// MARK: - Data Model

/// A single onboarding slide
private struct OnboardingStep: Identifiable {
    let id: Int
    let icon: String
    let title: LocalizedStringResource
    let description: LocalizedStringResource
}

/// The five protocol slides
private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(id: 0, icon: "shield.checkered",
                   title: LocalizedString.onboardingTitleProtocol,
                   description: LocalizedString.onboardingDescProtocol),
    OnboardingStep(id: 1, icon: "flag.fill",
                   title: LocalizedString.onboardingTitleClaiming,
                   description: LocalizedString.onboardingDescClaiming),
    OnboardingStep(id: 2, icon: "shippingbox.fill",
                   title: LocalizedString.onboardingTitleScavenging,
                   description: LocalizedString.onboardingDescScavenging),
    OnboardingStep(id: 3, icon: "antenna.radiowaves.left.and.right",
                   title: LocalizedString.onboardingTitleComms,
                   description: LocalizedString.onboardingDescComms),
    OnboardingStep(id: 4, icon: "arrow.triangle.2.circlepath",
                   title: LocalizedString.onboardingTitleEconomy,
                   description: LocalizedString.onboardingDescEconomy),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var breatheScale: CGFloat = 1.0

    private var isLastPage: Bool { currentPage == onboardingSteps.count - 1 }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.06),
                    Color(red: 0.10, green: 0.06, blue: 0.02),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle noise overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: headline + skip
                topBar

                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(onboardingSteps) { step in
                        slideView(step)
                            .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Footer: page indicator + button
                footer
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.12
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(LocalizedString.onboardingHeadline)
                .font(.caption)
                .fontWeight(.heavy)
                .tracking(2)
                .foregroundColor(ApocalypseTheme.primary.opacity(0.7))
                .minimumScaleFactor(0.5)

            Spacer()

            if !isLastPage {
                Button {
                    completeOnboarding()
                } label: {
                    Text(LocalizedString.onboardingSkip)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Slide View

    private func slideView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with breathing animation + glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ApocalypseTheme.primary.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(step.id == currentPage ? breatheScale : 1.0)

                // Icon circle
                Circle()
                    .stroke(ApocalypseTheme.primary.opacity(0.4), lineWidth: 2)
                    .frame(width: 120, height: 120)

                Image(systemName: step.icon)
                    .font(.system(size: 48, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ApocalypseTheme.primary)
                    .scaleEffect(step.id == currentPage ? breatheScale : 1.0)
            }

            // Title
            Text(step.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 32)

            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 24) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(onboardingSteps) { step in
                    Capsule()
                        .fill(step.id == currentPage
                              ? ApocalypseTheme.primary
                              : ApocalypseTheme.textMuted.opacity(0.4))
                        .frame(width: step.id == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // Action button
            Button {
                if isLastPage {
                    completeOnboarding()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            } label: {
                Text(isLastPage
                     ? LocalizedString.onboardingStartJourney
                     : LocalizedString.commonConfirm)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 48)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true))
}
