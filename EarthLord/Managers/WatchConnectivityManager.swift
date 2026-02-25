//
//  WatchConnectivityManager.swift
//  EarthLord
//
//  iOS-side WatchConnectivity bridge for the SectorZero Watch companion app.
//  Sends aetherEnergy, syncRate, and username to Watch via application context.
//  Handles "ping" messages from Watch with an energy reply.
//

import Foundation
import WatchConnectivity
import Combine
import Supabase

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published

    @Published private(set) var isWatchReachable: Bool = false
    @Published private(set) var lastPingReceived: Date?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var activated = false

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Activation

    /// Call from MainTabView.onSessionStart() after authentication is confirmed.
    /// Safe to call multiple times — only activates once.
    func activate() {
        guard WCSession.isSupported(), !activated else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
        setupObservers()
        debugLog("⌚ [WCM] WCSession activation requested")
    }

    // MARK: - Context Push

    /// Push latest state to Watch via application context (persisted through disconnection).
    func sendContextToWatch() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }

        let storeKit = StoreKitManager.shared
        let energy = storeKit.aetherEnergy
        let isInfinite = storeKit.isInfiniteEnergyEnabled
        let energyValue = isInfinite ? -1 : energy   // -1 = unlimited sentinel

        // syncRate: ACTIVE if presence was reported within the last 2 minutes
        let syncRate: String
        if let last = PlayerPresenceManager.shared.lastReportTime,
           Date().timeIntervalSince(last) < 120 {
            syncRate = "ACTIVE"
        } else {
            syncRate = "OFFLINE"
        }

        // Username: prefer metadata username, then email prefix, then fallback
        let user = AuthManager.shared.currentUser
        let username: String
        if let name = user?.userMetadata["username"]?.stringValue, !name.isEmpty {
            username = name
        } else if let email = user?.email,
                  let prefix = email.split(separator: "@").first {
            username = String(prefix)
        } else {
            username = "Survivor"
        }

        let context: [String: Any] = [
            "energy": energyValue,
            "syncRate": syncRate,
            "username": username,
            "tier": storeKit.currentMembershipTier.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            debugLog("⌚ [WCM] Context sent — energy:\(energyValue) sync:\(syncRate)")
        } catch {
            debugLog("⌚ [WCM] Failed to update application context: \(error)")
        }
    }

    // MARK: - Combine Observers

    private func setupObservers() {
        // Re-send on energy change (debounced to avoid rapid bursts)
        StoreKitManager.shared.$aetherEnergy
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.sendContextToWatch() }
            .store(in: &cancellables)

        // Re-send on tier change (instant — affects energy display)
        StoreKitManager.shared.$currentMembershipTier
            .sink { [weak self] _ in self?.sendContextToWatch() }
            .store(in: &cancellables)

        // Re-send when presence reports (updates syncRate chip)
        PlayerPresenceManager.shared.$lastReportTime
            .sink { [weak self] _ in self?.sendContextToWatch() }
            .store(in: &cancellables)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWatchReachable = session.isReachable
            if activationState == .activated {
                self.sendContextToWatch()
                debugLog("⌚ [WCM] Activated. Reachable: \(session.isReachable)")
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isWatchReachable = false
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isWatchReachable = false
            // Re-activate to support Watch pairing changes
            WCSession.default.activate()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWatchReachable = session.isReachable
            if session.isReachable {
                self.sendContextToWatch()
            }
        }
    }

    /// Handle ping messages from Watch (with reply handler).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["ping"] as? Bool == true else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastPingReceived = Date()
            debugLog("⌚ [WCM] Ping received from Watch")

            let storeKit = StoreKitManager.shared
            let energy = storeKit.aetherEnergy
            let isInfinite = storeKit.isInfiniteEnergyEnabled

            replyHandler([
                "pong": true,
                "energy": isInfinite ? -1 : energy,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }

    /// Handle ping messages without reply handler (fallback).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard message["ping"] as? Bool == true else { return }
        Task { @MainActor [weak self] in
            self?.lastPingReceived = Date()
            debugLog("⌚ [WCM] Ping (no-reply) received from Watch")
        }
    }
}
