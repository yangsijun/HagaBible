//
//  EditBookmarkSheet.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct EditBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss

    let bookmark: Bookmark
    var onSaved: () -> Void = {}

    @State private var selectedColor: BookmarkColor
    @State private var notes: String
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    var bookmarkRepository: any BookmarkRepository = DIContainer.shared.resolve(type: BookmarkRepository.self)

    init(bookmark: Bookmark, onSaved: @escaping () -> Void = {}) {
        self.bookmark = bookmark
        self.onSaved = onSaved
        self._selectedColor = State(initialValue: bookmark.color)
        self._notes = State(initialValue: bookmark.notes ?? "")
    }

    var body: some View {
        BookmarkFormContent(
            navigationTitle: "Edit Bookmark",
            bookCode: bookmark.bookCode,
            chapter: bookmark.chapter,
            startVerse: bookmark.startVerse,
            endVerse: bookmark.endVerse,
            selectedColor: $selectedColor,
            notes: $notes,
            errorMessage: $errorMessage,
            isSaving: isSaving,
            onCancel: { dismiss() },
            onSave: { saveBookmark() }
        )
        .presentationBackground(Color(uiColor: fontThemeManager.theme.backgroundColor))
    }

    private func saveBookmark() {
        isSaving = true
        let updated = Bookmark(
            id: bookmark.id,
            bookCode: bookmark.bookCode,
            bookOrder: bookmark.bookOrder,
            chapter: bookmark.chapter,
            startVerse: bookmark.startVerse,
            endVerse: bookmark.endVerse,
            color: selectedColor,
            notes: notes.isEmpty ? nil : notes,
            createdAt: bookmark.createdAt,
            updatedAt: Date()
        )
        Task {
            do {
                try await bookmarkRepository.update(updated)
                onSaved()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return EditBookmarkSheet(
        bookmark: Bookmark(
            id: UUID(),
            bookCode: "GEN",
            bookOrder: 1,
            chapter: 1,
            startVerse: 1,
            endVerse: 3,
            color: .yellow,
            notes: "좋은 말씀",
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
