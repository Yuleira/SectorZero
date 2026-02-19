//
//  DebugLog.swift
//  EarthLord
//
//  Debug-only logging helper.
//  Wraps print() so production builds emit nothing.
//

import Foundation

/// Print only in DEBUG builds. No-op in Release.
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
