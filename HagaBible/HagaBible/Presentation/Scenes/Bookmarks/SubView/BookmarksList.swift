//
//  BookmarksList.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct BookmarksList: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: BookmarksViewModel
    let onNavigate: (_ bookCode: String, _ chapter: Int, _ verseNum: Int) -> Void
    @Binding var editingBookmark: Bookmark?

    var body: some View {
        Group {
            if viewModel.bookmarks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        bookmarkRow(bookmark)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(id: bookmark.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingBookmark = bookmark
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No bookmarks")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onNavigate(bookmark.bookCode, bookmark.chapter, bookmark.startVerse)
            }
        } label: {
            HStack(spacing: 12) {
                Capsule()
                    .fill(bookmark.color.swiftUIColor)
                    .frame(width: 4, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(BibleReferenceFormatter.reference(book: bookmark.bookCode, for: bookmark))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let verseText = viewModel.verseTexts[bookmark.id], !verseText.isEmpty {
                        Text(verseText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let notes = bookmark.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.footnote)
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BookmarksListPreviewHost: View {
    let viewModel: BookmarksViewModel
    @State private var editing: Bookmark?

    var body: some View {
        BookmarksList(
            viewModel: viewModel,
            onNavigate: { _, _, _ in },
            editingBookmark: $editing
        )
    }
}

#Preview("Empty") {
    BookmarksListPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel(seed: [])
    )
}

#Preview("Mixed bookmarks") {
    BookmarksListPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel()
    )
}

#Preview("Single color (yellow)") {
    BookmarksListPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel(seed: [
            .previewSample(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 1,
                           color: .yellow, notes: "Note A"),
            .previewSample(bookCode: "EXO", bookOrder: 2, chapter: 3, startVerse: 14,
                           color: .yellow, notes: "Note B"),
            .previewSample(bookCode: "PSA", bookOrder: 19, chapter: 1, startVerse: 1, endVerse: 6,
                           color: .yellow, notes: nil),
        ])
    )
}

#Preview("Long-form note") {
    BookmarksListPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel(seed: [
            .previewSample(
                bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 1, endVerse: 31,
                color: .green,
                notes: "전체 장 북마크입니다. 이 노트는 의도적으로 매우 길게 작성되어 lineLimit이 2로 제한될 때 어떻게 truncate되는지 확인하기 위함입니다. SwiftUI의 Text는 이렇게 긴 문자열을 받아도 footnote 폰트에 맞춰 두 줄까지만 보이도록 잘라냅니다."
            )
        ])
    )
}
