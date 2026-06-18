//
//  ReadingReminder.swift
//  HagaBible
//

import Foundation

/// One entry in the alarm-style Reading Reminder list: a time, an optional label, and an
/// optional weekday-repeat selection.
///
/// `weekdays` uses `Calendar` weekday numbers (1 = Sunday … 7 = Saturday); an empty set
/// means "every day". `id` is stable and seeds the notification request identifier(s),
/// so editing or removing a reminder updates exactly its own pending notifications.
struct ReadingReminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int
    var label: String = ""
    var weekdays: Set<Int> = []
    var isEnabled: Bool = true

    /// All seven weekday numbers — the canonical "every day" set.
    static let everyday: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    /// Human-readable repeat summary: "Every day", "Weekdays", "Weekends", or a list of
    /// short day names ("Sun, Wed, Fri") in week order.
    var repeatDescription: String {
        if weekdays.isEmpty || weekdays == Self.everyday { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols // index 0 = Sunday
        return (1...7)
            .filter { weekdays.contains($0) }
            .map { symbols[$0 - 1] }
            .joined(separator: ", ")
    }
}
