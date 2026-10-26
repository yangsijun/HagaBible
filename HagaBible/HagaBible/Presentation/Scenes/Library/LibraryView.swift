//
//  LibraryView.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// Single tab hosting both the bookmark list and the reading checklist
/// (성경읽기표), switched via a top segmented control. Owns the one
/// NavigationStack; the section views provide only content + their own toolbar.
struct LibraryView: View {
    /// The window this Library belongs to; its reader supplies the version for verse text
    /// and book names, and its tabs are what the section views switch.
    @State private var window: WindowState
    @State private var bookmarksViewModel: BookmarksViewModel
    @State private var readingViewModel: ReadingChecklistViewModel
    @State private var fontThemeManager: FontThemeManager

    init(window: WindowState) {
        let bibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)
        _window = State(initialValue: window)
        _bookmarksViewModel = State(initialValue: BookmarksViewModel(
            appState: DIContainer.shared.resolve(type: AppState.self),
            reader: window.reader,
            bookmarkRepository: DIContainer.shared.resolve(type: BookmarkRepository.self),
            bibleRepository: bibleRepository
        ))
        _readingViewModel = State(initialValue: ReadingChecklistViewModel(
            window: window,
            readingMarkRepository: DIContainer.shared.resolve(type: ReadingMarkRepository.self),
            bibleRepository: bibleRepository
        ))
        _fontThemeManager = State(initialValue: DIContainer.shared.resolve(type: FontThemeManager.self))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch window.librarySection {
                case .bookmarks:
                    BookmarksSectionView(viewModel: bookmarksViewModel, onNavigate: navigateToReader)
                        .transition(.opacity)
                case .reading:
                    ReadingChecklistView(viewModel: readingViewModel)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Animating the binding wraps the whole switch in one
                    // transaction, so the content crossfades AND the bookmark
                    // search bar animates in/out together (no abrupt nav-bar jump).
                    Picker("Library section", selection: $window.librarySection.animation(.easeInOut(duration: 0.25))) {
                        Text("Bookmarks").tag(LibrarySection.bookmarks)
                        Text("Reading").tag(LibrarySection.reading)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }
            .onChange(of: window.selectedTab) { _, tab in
                // Re-entering the Library tab: refresh bookmarks (the reader may
                // have added/removed some) and reload the checklist's book list if
                // the reader's version changed — book names are version-specific.
                if tab == .library {
                    Task { await bookmarksViewModel.refresh() }
                    Task { await readingViewModel.reloadIfVersionChanged() }
                }
            }
        }
    }

    private func navigateToReader(bookCode: String, chapter: Int, verseNum: Int) {
        Task {
            await window.showReader(bookCode: bookCode, chapter: chapter, verse: verseNum)
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    let window = DIContainer.makeWindowState()
    return LibraryView(window: window)
        .environment(window.reader)
}
