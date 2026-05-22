//
//  ReadingChecklistToolbarContent.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// Trailing toolbar for the reading checklist: a trash button that resets every
/// chapter to unread, guarded by a confirmation dialog anchored to the button.
struct ReadingChecklistToolbarContent: ToolbarContent {
    let viewModel: ReadingChecklistViewModel
    @Binding var showResetConfirmation: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset all reading progress", systemImage: "trash")
            }
            .disabled(viewModel.overallRead == 0)
            // Anchor the dialog to the button so the iPad popover points at it.
            .confirmationDialog(
                "Reset all reading progress?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    viewModel.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This marks every chapter unread. This cannot be undone.")
            }
        }
    }
}
