//
//  ExperimentalFeaturePreferences.swift
//  HagaBible
//

import Foundation

/// Centralized access to the experimental ("Labs") feature flags so their keys live
/// in one place (mirrors `BookmarkPreferences` / `ComparePreferences`).
///
/// All default to **off**: text-to-speech ("Listen"), voice recording and page-turning
/// reading are opt-in lab features the user turns on from the reader's "Labs" sheet.
/// `UserDefaults.bool(forKey:)` returns `false` when the key is absent, which is
/// exactly the opt-in default we want — no explicit registration needed.
enum ExperimentalFeaturePreferences {
    private static let ttsEnabledKey = "experimental.ttsEnabled"
    private static let recordingEnabledKey = "experimental.recordingEnabled"
    private static let pagedReadingEnabledKey = "experimental.pagedReadingEnabled"
    private static let pagedSpreadEnabledKey = "experimental.pagedSpreadEnabled"

    static var isTTSEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: ttsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: ttsEnabledKey) }
    }

    static var isRecordingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: recordingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: recordingEnabledKey) }
    }

    /// Book-style reader: page turning instead of scrolling (two pages in landscape).
    static var isPagedReadingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: pagedReadingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: pagedReadingEnabledKey) }
    }

    /// Two pages side by side in landscape / half-folded page mode. Unlike the other
    /// flags this defaults to **on**, so an absent key reads as `true`.
    static var isPagedSpreadEnabled: Bool {
        get { UserDefaults.standard.object(forKey: pagedSpreadEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: pagedSpreadEnabledKey) }
    }
}
