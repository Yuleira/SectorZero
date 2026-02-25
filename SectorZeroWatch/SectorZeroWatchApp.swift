//
//  SectorZeroWatchApp.swift
//  SectorZero Watch
//
//  Main entry point for the SectorZero Apple Watch companion app.
//

import SwiftUI

@main
struct SectorZeroWatchApp: App {

    @StateObject private var connectivity = WatchConnectivityReceiver.shared

    var body: some Scene {
        WindowGroup {
            WatchStatusView()
                .environmentObject(connectivity)
        }
    }
}
