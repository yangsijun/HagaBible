//
//  LibraryView.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

enum LibrarySection: Hashable {
    case bookmarks
    case reading
}

/// Single tab hosting both the bookmark list and the reading checklist
/// (성경읽기표), switched via a top segmented control. Owns the one
/// NavigationStack; the section views provide only content + their own toolbar.
struct LibraryView: View {
    @State private var appState: AppState
    @State private var bookmarksViewModel: BookmarksViewModel
    @State private var readingViewModel: ReadingChecklistViewModel
    @State private var fontThemeManager: FontThemeManager
    @State private var section: LibrarySection = .bookmarks

    init() {
        let appState = DIContainer.shared.resolve(type: AppState.self)
        let bibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)
        _appState = State(initialValue: appState)
        _bookmarksViewModel = State(initialValue: BookmarksViewModel(
            appState: appState,
            bookmarkRepository: DIContainer.shared.resolve(type: BookmarkRepository.self),
            bibleRepository: bibleRepository
        ))
        _readingViewModel = State(initialValue: ReadingChecklistViewModel(
            appState: appState,
            readingMarkRepository: DIContainer.shared.resolve(type: ReadingMarkRepository.self),
            bibleRepository: bibleRepository
        ))
        _fontThemeManager = State(initialValue: DIContainer.shared.resolve(type: FontThemeManager.self))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch section {
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
                    Picker("Library section", selection: $section.animation(.easeInOut(duration: 0.25))) {
                        Text("Bookmarks").tag(LibrarySection.bookmarks)
                        Text("Reading").tag(LibrarySection.reading)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }
            .onChange(of: appState.selectedTab) { _, tab in
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
        let readerViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
        Task {
            readerViewModel.navigatedVerseNum = verseNum
            await readerViewModel.applyBibleSelectionAsync(
                bookCode: bookCode,
                chapterNum: chapter,
                verseNum: verseNum
            )
            // Switch tabs only after the selection is applied, so the reader's
            // onChange(selectedTab) refreshes stripes for the new chapter, not the old.
            appState.selectedTab = .bibleReader
            readerViewModel.bibleNavigationUpdateTrigger.toggle()
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return LibraryView()
}
