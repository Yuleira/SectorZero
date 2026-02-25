//
//  WatchStatusView.swift
//  SectorZero Watch
//
//  Main Watch face: aether energy gauge, sync status chip, Ping button.
//  Matches ApocalypseTheme: black background, orange accent.
//

import SwiftUI

struct WatchStatusView: View {

    @EnvironmentObject private var connectivity: WatchConnectivityReceiver
    @State private var isPinging = false
    @State private var pingSuccess = false

    // Orange = ApocalypseTheme.primary (1.0, 0.4, 0.1)
    private let accentOrange = Color(red: 1.0, green: 0.4, blue: 0.1)

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // Username header
                Text(connectivity.username)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .padding(.top, 4)

                // Energy gauge
                energyGauge

                // Sync status chip
                syncChip

                // Ping button
                pingButton

                // Status footnote
                footNote
            }
            .padding(.horizontal, 8)
        }
        .background(Color.black)
        .onAppear {
            WatchConnectivityReceiver.shared.activate()
        }
    }

    // MARK: - Energy Gauge

    private var energyGauge: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 7)

            // Fill ring
            Circle()
                .trim(from: 0, to: energyFraction)
                .stroke(
                    accentOrange,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: energyFraction)

            // Centre label
            VStack(spacing: 2) {
                if connectivity.isUnlimitedEnergy {
                    Image(systemName: "infinity")
                        .font(.title3.weight(.bold))
                        .foregroundColor(accentOrange)
                } else {
                    Text("\(connectivity.aetherEnergy)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(accentOrange)
                }
                Text("ENERGY")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 84, height: 84)
    }

    // MARK: - Sync Chip

    private var syncChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(syncColor)
                .frame(width: 6, height: 6)
            Text(connectivity.syncRate)
                .font(.caption2.weight(.semibold))
                .foregroundColor(syncColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(syncColor.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Ping Button

    private var pingButton: some View {
        Button {
            sendPing()
        } label: {
            HStack(spacing: 5) {
                if isPinging {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.65)
                        .tint(.white)
                } else {
                    Image(systemName: pingSuccess
                          ? "checkmark.circle.fill"
                          : "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                }
                Text(isPinging ? "Pinging…" : "PING")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(connectivity.isPhoneReachable
                        ? accentOrange
                        : accentOrange.opacity(0.4))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPinging || !connectivity.isPhoneReachable)

        // Unreachable hint
        .overlay(alignment: .bottom) {
            if !connectivity.isPhoneReachable {
                Text("Phone unreachable")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .offset(y: 16)
            }
        }
    }

    // MARK: - Foot Note

    @ViewBuilder
    private var footNote: some View {
        if let updated = connectivity.lastUpdated {
            Text("Updated \(updated, style: .relative) ago")
                .font(.system(size: 9))
                .foregroundColor(Color.gray.opacity(0.6))
                .padding(.top, connectivity.isPhoneReachable ? 0 : 12)
        }
    }

    // MARK: - Helpers

    private var energyFraction: CGFloat {
        if connectivity.isUnlimitedEnergy { return 1.0 }
        let maxEnergy: CGFloat = 50   // highest energy pack = 50
        return min(CGFloat(connectivity.aetherEnergy) / maxEnergy, 1.0)
    }

    private var syncColor: Color {
        connectivity.syncRate == "ACTIVE" ? .green : .red
    }

    private func sendPing() {
        guard !isPinging else { return }
        isPinging = true
        pingSuccess = false
        connectivity.sendPing()

        // Show result after 3 s (generous timeout for round-trip)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isPinging = false
            pingSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                pingSuccess = false
            }
        }
    }
}

#Preview {
    WatchStatusView()
        .environmentObject(WatchConnectivityReceiver.shared)
}
