//
//  ReadingReminderPreferences.swift
//  HagaBible
//

import Foundation

/// Centralized persistence for the Reading Reminder list (UserDefaults, JSON-encoded), so
/// the key lives in one place (mirrors `ScreenDisplayPreferences` /
/// `ExperimentalFeaturePreferences`). Defaults to an empty list.
enum ReadingReminderPreferences {
    private static let remindersKey = "readingReminder.items"

    /// Default time (09:00) seeded into a freshly added reminder.
    static let defaultHour = 9
    static let defaultMinute = 0

    static var reminders: [ReadingReminder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: remindersKey),
                  let decoded = try? JSONDecoder().decode([ReadingReminder].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }
}
