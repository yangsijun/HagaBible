//
//  BookmarkPreferences.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import Foundation

/// Centralized access to bookmark-related UserDefaults so keys live in one place.
enum BookmarkPreferences {
    private static let lastColorKey = "lastBookmarkColor"
    private static let indicatorEnabledKey = "bookmarkIndicatorEnabled"

    /// The color used for the most recent bookmark; defaults to `.yellow`.
    static var lastColor: BookmarkColor {
        get {
            let raw = UserDefaults.standard.string(forKey: lastColorKey) ?? ""
            return BookmarkColor(rawValue: raw) ?? .yellow
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: lastColorKey) }
    }

    /// Whether the per-verse bookmark indicator is shown in the reader; defaults to `true`.
    static var isIndicatorEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: indicatorEnabledKey) == nil
                ? true
                : UserDefaults.standard.bool(forKey: indicatorEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: indicatorEnabledKey) }
    }
}
