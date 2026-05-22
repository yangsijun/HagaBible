//
//  BookmarksSectionView.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// Bookmark list content for embedding inside the Library tab. Carries no
/// NavigationStack/title of its own — the host (`LibraryView`) owns the
/// navigation chrome and the section segmented control.
struct BookmarksSectionView: View {
    @Bindable var viewModel: BookmarksViewModel
    let onNavigate: (_ bookCode: String, _ chapter: Int, _ verseNum: Int) -> Void

    @State private var editingBookmark: Bookmark?

    var body: some View {
        VStack(spacing: 0) {
            BookmarksFilterBar(viewModel: viewModel)
            BookmarksList(
                viewModel: viewModel,
                onNavigate: onNavigate,
                editingBookmark: $editingBookmark
            )
        }
        .searchable(
            text: $viewModel.keyword,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search notes or reference"
        )
        .onChange(of: viewModel.keyword) { _, _ in
            Task { await viewModel.load() }
        }
        .toolbar {
            BookmarksToolbarContent(viewModel: viewModel)
        }
        .task {
            // First appear only — re-entering the tab refreshes via LibraryView's
            // onChange, and segment switches must not trigger the heavy reload.
            if !viewModel.hasLoaded {
                await viewModel.refresh()
            }
        }
        .sheet(item: $editingBookmark) { bookmark in
            EditBookmarkSheet(bookmark: bookmark) {
                Task { await viewModel.load() }
            }
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return NavigationStack {
        BookmarksSectionView(
            viewModel: BookmarksPreviewFactory.makeViewModel(),
            onNavigate: { _, _, _ in }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
