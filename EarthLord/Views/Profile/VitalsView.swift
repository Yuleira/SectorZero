//
//  VitalsView.swift
//  EarthLord
//
//  Static vitals UI with hardcoded values
//

import SwiftUI

struct VitalsView: View {
    var body: some View {
        VStack(spacing: 16) {
            activeBuffsCard
            coreHealthCard
            basicVitalsCard
        }
    }

    // MARK: - Active Buffs

    private var activeBuffsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text(LocalizedString.vitalsActiveBuffs)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(LocalizedString.vitalsNoActiveBuffs)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(LocalizedString.vitalsBuffHint)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Core Health

    private var coreHealthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text(LocalizedString.vitalsCoreHealth)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Text("100/100")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.success)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.success)
                        .frame(width: geo.size.width, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Basic Vitals

    private var basicVitalsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.clipboard")
                    .foregroundColor(ApocalypseTheme.info)
                Text(LocalizedString.vitalsBasicVitals)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(ApocalypseTheme.success)
                        .frame(width: 6, height: 6)
                    Text(LocalizedString.vitalsStatusGood)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ApocalypseTheme.success.opacity(0.15))
                .cornerRadius(8)
            }

            // Fullness
            vitalRow(
                icon: "fork.knife",
                iconColor: .orange,
                label: LocalizedString.vitalsFullness,
                value: "90%",
                progress: 0.90,
                barColor: .orange
            )

            // Hydration
            vitalRow(
                icon: "drop.fill",
                iconColor: .blue,
                label: LocalizedString.vitalsHydration,
                value: "81%",
                progress: 0.81,
                barColor: .blue
            )

            // Tip
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(LocalizedString.vitalsTip)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(8)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func vitalRow(
        icon: String,
        iconColor: Color,
        label: LocalizedStringResource,
        value: String,
        progress: Double,
        barColor: Color
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
