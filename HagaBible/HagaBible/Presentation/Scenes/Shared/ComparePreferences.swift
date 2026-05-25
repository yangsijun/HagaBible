//
//  ComparePreferences.swift
//  HagaBible
//
//  Created by 양시준 on 5/22/26.
//

import Foundation

/// Centralized access to translation-comparison (역본 대조) UserDefaults so the
/// key lives in one place, mirroring `BookmarkPreferences`.
enum ComparePreferences {
    private static let compareVersionCodeKey = "compareVersionCode"

    /// The version code shown beneath each verse for side-by-side comparison;
    /// `nil` means comparison is off. Persisted across launches.
    static var compareVersionCode: String? {
        get { UserDefaults.standard.string(forKey: compareVersionCodeKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: compareVersionCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: compareVersionCodeKey)
            }
        }
    }
}
