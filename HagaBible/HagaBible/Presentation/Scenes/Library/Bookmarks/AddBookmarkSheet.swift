//
//  AddBookmarkSheet.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct AddBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss

    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let startVerse: Int
    let endVerse: Int
    var onSaved: () -> Void = {}

    @State private var selectedColor: BookmarkColor = BookmarkPreferences.lastColor
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @State private var detent: PresentationDetent = .medium

    var bookmarkRepository: any BookmarkRepository = DIContainer.shared.resolve(type: BookmarkRepository.self)

    var body: some View {
        BookmarkFormContent(
            navigationTitle: "Add Bookmark",
            bookCode: bookCode,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
            selectedColor: $selectedColor,
            notes: $notes,
            errorMessage: $errorMessage,
            isSaving: isSaving,
            onCancel: { dismiss() },
            onSave: { saveBookmark() }
        )
        .halfSheetPresentation(detent: $detent, themeBackgroundColor: fontThemeManager.theme.backgroundColor)
    }

    private func saveBookmark() {
        isSaving = true
        let bookmark = Bookmark(
            id: UUID(),
            bookCode: bookCode,
            bookOrder: bookOrder,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
            color: selectedColor,
            notes: notes.isEmpty ? nil : notes,
            createdAt: Date(),
            updatedAt: Date()
        )
        Task {
            do {
                try await bookmarkRepository.insert(bookmark)
                BookmarkPreferences.lastColor = selectedColor
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
    return AddBookmarkSheet(
        bookCode: "GEN",
        bookOrder: 1,
        chapter: 1,
        startVerse: 1,
        endVerse: 3
    )
}
