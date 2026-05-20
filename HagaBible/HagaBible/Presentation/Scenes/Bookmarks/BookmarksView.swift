//
//  BookmarksView.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss

    var onNavigate: (_ bookCode: String, _ chapter: Int, _ verseNum: Int) -> Void = { _, _, _ in }

    @State private var viewModel: BookmarksViewModel = BookmarksViewModel(
        appState: DIContainer.shared.resolve(type: AppState.self),
        bookmarkRepository: DIContainer.shared.resolve(type: BookmarkRepository.self),
        bibleRepository: DIContainer.shared.resolve(type: BibleRepository.self)
    )
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @State private var editingBookmark: Bookmark?
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BookmarksFilterBar(viewModel: viewModel)
                BookmarksList(
                    viewModel: viewModel,
                    onNavigate: onNavigate,
                    editingBookmark: $editingBookmark
                )
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.keyword,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search notes or reference"
            )
            .onChange(of: viewModel.keyword) { _, _ in
                Task { await viewModel.load() }
            }
            .toolbar {
                BookmarksToolbarContent(viewModel: viewModel) {
                    dismiss()
                }
            }
            .task {
                await viewModel.refresh()
            }
            .sheet(item: $editingBookmark) { bookmark in
                EditBookmarkSheet(bookmark: bookmark) {
                    Task { await viewModel.load() }
                }
            }
        }
        .halfSheetPresentation(detent: $detent, themeBackgroundColor: fontThemeManager.theme.backgroundColor)
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BookmarksView()
}
