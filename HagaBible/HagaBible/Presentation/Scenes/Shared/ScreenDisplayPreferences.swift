//
//  ScreenDisplayPreferences.swift
//  HagaBible
//

import Foundation

/// Centralized access to the reader's screen-wake/display UserDefaults so the
/// keys live in one place (mirrors `BookmarkPreferences` / `ComparePreferences`).
///
/// Defaults preserve the app's original behavior — the reader keeps the screen
/// on and never dims it. `keepScreenOn` is persisted as its inverse
/// (`allowAutoLock`) so the absent-key default (`UserDefaults.bool` → `false`)
/// maps to "keep the screen on", and `dimAfterSeconds` defaults to `0` ("never
/// dim") for the same reason.
enum ScreenDisplayPreferences {
    private static let allowAutoLockKey = "display.allowAutoLock"
    private static let dimAfterSecondsKey = "display.dimAfterSeconds"

    /// When `true` the reader prevents the display from auto-locking; when
    /// `false` iOS dims and locks the screen normally per the device's
    /// Auto-Lock setting. Defaults to `true` (the original behavior).
    static var keepScreenOn: Bool {
        get { !UserDefaults.standard.bool(forKey: allowAutoLockKey) }
        set { UserDefaults.standard.set(!newValue, forKey: allowAutoLockKey) }
    }

    /// Seconds of inactivity before the reader dims the screen while keeping it
    /// on; `0` means never dim. Only applies when `keepScreenOn` is `true`.
    static var dimAfterSeconds: Int {
        get { UserDefaults.standard.integer(forKey: dimAfterSecondsKey) }
        set { UserDefaults.standard.set(newValue, forKey: dimAfterSecondsKey) }
    }
}
