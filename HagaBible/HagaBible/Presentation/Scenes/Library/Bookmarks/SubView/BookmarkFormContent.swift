//
//  BookmarkFormContent.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import SwiftUI

/// Shared form body for adding and editing a bookmark. The add/edit sheets supply
/// the verse coordinates, bindings, and a save action; this view owns the layout,
/// verse-text loading, color picker, notes editor, toolbar, and error alert.
struct BookmarkFormContent: View {
    let navigationTitle: String
    let bookCode: String
    let chapter: Int
    let startVerse: Int
    let endVerse: Int

    @Binding var selectedColor: BookmarkColor
    @Binding var notes: String
    @Binding var errorMessage: String?
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var reference: String = ""
    @State private var verseText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Verse") {
                    BookmarkVerseHeader(reference: reference, verseText: verseText)
                }

                Section("Color") {
                    colorChipsRow
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadVerse() }
        }
    }

    private var colorChipsRow: some View {
        HStack(spacing: 12) {
            ForEach(BookmarkColor.allCases, id: \.self) { color in
                BookmarkColorChip(color: color, isSelected: selectedColor == color, size: 32) {
                    selectedColor = color
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func loadVerse() async {
        reference = BibleReferenceFormatter.reference(
            book: bookCode, chapter: chapter, startVerse: startVerse, endVerse: endVerse
        )
        let loader = VerseTextLoader()
        guard let loaded = await loader.loadVerseText(
            bookCode: bookCode, chapter: chapter, startVerse: startVerse, endVerse: endVerse
        ) else { return }
        reference = BibleReferenceFormatter.reference(
            book: loaded.bookName ?? bookCode, chapter: chapter, startVerse: startVerse, endVerse: endVerse
        )
        verseText = loaded.text
    }
}
