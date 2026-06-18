//
//  NotificationService.swift
//  HagaBible
//

import Foundation
import OSLog
import UserNotifications

/// Schedules the Reading Reminder list as local notifications.
///
/// Each enabled `ReadingReminder` becomes one repeating `UNCalendarNotificationTrigger`
/// per scheduled day — a single daily trigger when no weekdays are selected, otherwise
/// one weekly trigger per selected weekday. Every request shares `Self.identifierPrefix`,
/// so `syncReadingReminders(_:)` can reconcile the OS state to the current list by
/// clearing our pending requests and re-adding the enabled ones.
///
/// Foreground presentation is intentionally not handled: a reminder's purpose is to pull
/// the user back when the app is closed/backgrounded, and iOS suppresses it while the app
/// is foreground (where the user is already reading).
final class NotificationService {
    /// Shared prefix for every reading-reminder request identifier, so we can find and
    /// clear exactly our own pending notifications.
    static let identifierPrefix = "haga.readingReminder."

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorization

    /// The current notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Whether the current status permits delivering notifications.
    func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Request alert + sound permission, returning whether it was granted. Safe to call
    /// repeatedly: once the decision is made iOS reports it without prompting again.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Logger.notification.error("Authorization request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Reconcile pending notifications to `reminders`: clear all of ours, then re-add the
    /// enabled ones. Safe to call on every change to the list.
    func syncReadingReminders(_ reminders: [ReadingReminder]) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }

        for reminder in reminders where reminder.isEnabled {
            for request in Self.requests(for: reminder) {
                do {
                    try await center.add(request)
                } catch {
                    Logger.notification.error("Failed to schedule reminder: \(error.localizedDescription)")
                }
            }
        }
        Logger.notification.debug("Synced \(reminders.filter(\.isEnabled).count) enabled reading reminder(s)")
    }

    /// The notification request(s) for one reminder: a single daily trigger when no
    /// weekdays are selected, otherwise one weekly trigger per selected weekday.
    private static func requests(for reminder: ReadingReminder) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = reminder.label.isEmpty ? "Time to read the Bible" : reminder.label
        content.body = "Take a moment to read God's Word today."
        content.sound = .default

        func request(idSuffix: String, _ components: DateComponents) -> UNNotificationRequest {
            UNNotificationRequest(
                identifier: identifierPrefix + reminder.id.uuidString + idSuffix,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }

        if reminder.weekdays.isEmpty {
            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute
            return [request(idSuffix: "", components)]
        }

        return reminder.weekdays.sorted().map { weekday in
            var components = DateComponents()
            components.weekday = weekday
            components.hour = reminder.hour
            components.minute = reminder.minute
            return request(idSuffix: "-\(weekday)", components)
        }
    }
}
