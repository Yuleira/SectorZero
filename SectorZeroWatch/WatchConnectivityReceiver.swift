//
//  WatchConnectivityReceiver.swift
//  SectorZero Watch
//
//  Watch-side WCSession delegate.
//  Receives application context from iPhone, publishes state for WatchStatusView.
//

import Foundation
import WatchConnectivity

final class WatchConnectivityReceiver: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityReceiver()

    // MARK: - Published State

    /// Current aether energy. -1 on phone means unlimited (Archon tier).
    @Published private(set) var aetherEnergy: Int = 0
    @Published private(set) var isUnlimitedEnergy: Bool = false
    @Published private(set) var syncRate: String = "OFFLINE"
    @Published private(set) var username: String = "Survivor"
    @Published private(set) var isPhoneReachable: Bool = false
    @Published private(set) var lastUpdated: Date?

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Activation

    /// Call once from WatchStatusView.onAppear.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Ping

    /// Send a ping to the iPhone to get the latest energy value.
    func sendPing() {
        guard WCSession.default.isReachable else { return }
        let message: [String: Any] = [
            "ping": true,
            "timestamp": Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let energyVal = reply["energy"] as? Int {
                    let unlimited = energyVal == -1
                    self?.isUnlimitedEnergy = unlimited
                    self?.aetherEnergy = unlimited ? 0 : energyVal
                }
                self?.lastUpdated = Date()
            }
        }, errorHandler: { error in
            print("[WatchReceiver] Ping error: \(error.localizedDescription)")
        })
    }

    // MARK: - Context Parsing

    private func applyContext(_ context: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let energyVal = context["energy"] as? Int {
                self.isUnlimitedEnergy = (energyVal == -1)
                self.aetherEnergy = self.isUnlimitedEnergy ? 0 : energyVal
            }
            if let rate = context["syncRate"] as? String {
                self.syncRate = rate
            }
            if let name = context["username"] as? String, !name.isEmpty {
                self.username = name
            }
            self.lastUpdated = Date()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityReceiver: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        // Apply any previously cached context from last phone session
        if !session.receivedApplicationContext.isEmpty {
            applyContext(session.receivedApplicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        applyContext(applicationContext)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        applyContext(message)
    }
}
