//
//  PlatformHelper.swift
//  HagaBible
//
//  Created by 양시준 on 1/26/26.
//

import Foundation

/// Utility for runtime platform detection.
/// Compile-time `#if os(macOS)` doesn't work for iOS apps running on Mac via "Designed for iPad" mode.
enum PlatformHelper {
    /// Returns `true` if the iOS app is running on macOS (Apple Silicon Mac).
    static var isRunningOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }
}
