//
//  ExperimentalFeaturePreferences.swift
//  HagaBible
//

import Foundation

/// Centralized access to the experimental ("Labs") feature flags so their keys live
/// in one place (mirrors `BookmarkPreferences` / `ComparePreferences`).
///
/// Both default to **off**: text-to-speech ("Listen") and voice recording are
/// opt-in lab features the user turns on from the reader's "Labs" sheet.
/// `UserDefaults.bool(forKey:)` returns `false` when the key is absent, which is
/// exactly the opt-in default we want — no explicit registration needed.
enum ExperimentalFeaturePreferences {
    private static let ttsEnabledKey = "experimental.ttsEnabled"
    private static let recordingEnabledKey = "experimental.recordingEnabled"

    static var isTTSEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: ttsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: ttsEnabledKey) }
    }

    static var isRecordingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: recordingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: recordingEnabledKey) }
    }
}
