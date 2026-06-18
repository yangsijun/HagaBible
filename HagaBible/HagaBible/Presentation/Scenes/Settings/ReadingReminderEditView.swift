//
//  ReadingReminderEditView.swift
//  HagaBible
//

import SwiftUI

/// Add/edit sheet for a single `ReadingReminder` — a time wheel, an optional label, and a
/// weekday-repeat picker (no days selected = every day). Edits a local `draft` and only
/// commits via `onSave` when the user taps "Done", so "Cancel" discards cleanly. When
/// editing an existing reminder, `onDelete` adds a destructive "Delete Reminder" row.
struct ReadingReminderEditView: View {
    @State private var draft: ReadingReminder
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    let onSave: (ReadingReminder) -> Void
    let onDelete: (() -> Void)?

    init(
        reminder: ReadingReminder,
        isNew: Bool,
        onSave: @escaping (ReadingReminder) -> Void,
        onDelete: (() -> Void)?
    ) {
        _draft = State(initialValue: reminder)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    /// Bridges the wheel `DatePicker` (which works in `Date`) to the reminder's
    /// hour/minute fields, ignoring the date part.
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: draft.hour, minute: draft.minute)) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                draft.hour = components.hour ?? draft.hour
                draft.minute = components.minute ?? draft.minute
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Section {
                    TextField("Label", text: $draft.label)
                }

                Section("Repeat") {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            HStack {
                                Text("Every \(weekdayName(weekday))")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if draft.weekdays.contains(weekday) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        // Plain text/checkmark, no accent: the Form's automatic button
                        // style otherwise tints the row's label with the accent color.
                        .tint(Color.primary)
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isNew ? "Add Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(draft)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                }
            }
        }
        .tint(.accent)
        .presentationBackground(Color(uiColor: fontThemeManager.theme.backgroundColor))
    }

    private func toggleWeekday(_ weekday: Int) {
        if draft.weekdays.contains(weekday) {
            draft.weekdays.remove(weekday)
        } else {
            draft.weekdays.insert(weekday)
        }
    }

    /// Full weekday name for `weekday` (1 = Sunday … 7 = Saturday).
    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}

#Preview {
    DIContainer.registerForPreview()
    return ReadingReminderEditView(
        reminder: ReadingReminder(hour: 9, minute: 0),
        isNew: true,
        onSave: { _ in },
        onDelete: nil
    )
}
