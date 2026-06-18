//
//  ReadingReminderView.swift
//  HagaBible
//

import SwiftUI
import UIKit

/// "Reading Reminders" — an alarm-style list of Bible-reading reminders. Add with "+",
/// tap a row to edit, toggle each on/off, swipe (or Edit) to delete. Bound to the shared
/// `AppState` (persisted via `ReadingReminderPreferences`); the OS schedule is reconciled
/// through `NotificationService` on every change. Reached from the reader's "Other (…)"
/// toolbar menu.
///
/// Styling matches the sibling Labs / Font & Themes sheets: a transparent list/form over
/// the themed page background, with accent-tinted controls.
struct ReadingReminderView: View {
    @Bindable var appState: AppState
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    @State private var isAddingReminder = false
    @State private var editingReminder: ReadingReminder?
    @State private var showPermissionDeniedAlert = false
    @State private var editMode: EditMode = .inactive

    private var notificationService: NotificationService {
        DIContainer.shared.resolve(type: NotificationService.self)
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.readingReminders.isEmpty {
                    emptyState
                } else {
                    reminderList
                }
            }
            .navigationTitle("Reading Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !appState.readingReminders.isEmpty {
                        // Custom edit toggle instead of `EditButton()`: the system Done
                        // state picks up a prominent (filled) background on iOS 26. This
                        // shows plain "Edit" text → a checkmark icon, both in `.primary`
                        // with the standard (non-prominent) toolbar glass.
                        Button {
                            withAnimation {
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                        } label: {
                            if editMode.isEditing {
                                Image(systemName: "checkmark")
                            } else {
                                Text("Edit")
                            }
                        }
                        .tint(Color.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAddingReminder = true } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Color.primary)
                }
            }
            .environment(\.editMode, $editMode)
        }
        .tint(.accent)
        .presentationBackground(Color(uiColor: fontThemeManager.theme.backgroundColor))
        .sheet(isPresented: $isAddingReminder) {
            ReadingReminderEditView(
                reminder: ReadingReminder(
                    hour: ReadingReminderPreferences.defaultHour,
                    minute: ReadingReminderPreferences.defaultMinute
                ),
                isNew: true,
                onSave: { appState.readingReminders.append($0) },
                onDelete: nil
            )
        }
        .sheet(item: $editingReminder) { reminder in
            ReadingReminderEditView(
                reminder: reminder,
                isNew: false,
                onSave: { updated in
                    if let index = appState.readingReminders.firstIndex(where: { $0.id == updated.id }) {
                        appState.readingReminders[index] = updated
                    }
                },
                onDelete: {
                    appState.readingReminders.removeAll { $0.id == reminder.id }
                }
            )
        }
        .onChange(of: appState.readingReminders) { _, reminders in
            Task { await syncReminders(reminders) }
        }
        .alert("Notifications are off", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To get reading reminders, allow notifications for HagaBible in Settings.")
        }
    }

    private var reminderList: some View {
        List {
            ForEach($appState.readingReminders) { $reminder in
                ReadingReminderRow(reminder: $reminder) {
                    editingReminder = reminder
                }
            }
            .onDelete { appState.readingReminders.remove(atOffsets: $0) }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Reminders", systemImage: "bell.slash")
        } description: {
            Text("Add a reminder to read the Bible at the time you choose.")
        } actions: {
            Button("Add Reminder") { isAddingReminder = true }
        }
    }

    /// Reconcile the OS schedule with the list — prompting for permission the first time
    /// an enabled reminder exists, and flagging when notifications are off.
    private func syncReminders(_ reminders: [ReadingReminder]) async {
        if reminders.contains(where: \.isEnabled) {
            if await notificationService.authorizationStatus() == .notDetermined {
                _ = await notificationService.requestAuthorization()
            }
            let authorized = await notificationService.isAuthorized()
            if !authorized {
                showPermissionDeniedAlert = true
            }
        }
        await notificationService.syncReadingReminders(reminders)
    }
}

/// One row in the reminder list: time + label/repeat summary on the left (tap to edit),
/// an on/off toggle on the right. Dimmed while off, like the Clock app.
private struct ReadingReminderRow: View {
    @Binding var reminder: ReadingReminder
    let onTap: () -> Void

    private var time: Date {
        Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? Date()
    }

    private var subtitle: String {
        reminder.label.isEmpty
            ? reminder.repeatDescription
            : "\(reminder.label) · \(reminder.repeatDescription)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(time, format: .dateTime.hour().minute())
                    .font(.largeTitle)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(reminder.isEnabled ? 1 : 0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            Toggle("", isOn: $reminder.isEnabled)
                .labelsHidden()
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return ReadingReminderView(appState: DIContainer.shared.resolve(type: AppState.self))
}
