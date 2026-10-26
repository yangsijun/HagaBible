//
//  WindowState.swift
//  HagaBible
//
//  Created by 양시준 on 10/26/26.
//

import Foundation
import Observation

/// State that belongs to one window (scene), not to the app. iPad and foldables can show
/// the app in several windows at once, each on its own tab, chapter and translation, so
/// everything two windows must not share lives here: the tab selection, the Library routing
/// and the reader/navigation view models. App-wide settings and persistence stay in
/// `AppState`. `RootView` owns one per window and hands it down through the environment.
@Observable
@MainActor
final class WindowState {
    var selectedTab: TabIdentifier = .bibleReader

    /// Which Library segment to show. The reader's toolbar routes to a specific section
    /// (Bookmarks or 성경읽기표) when it switches to the tab.
    var librarySection: LibrarySection = .bookmarks

    /// Book order (1–66) the 성경읽기표 should scroll to when the Library tab opens, set by
    /// the reader's "Reading Checklist" toolbar action; cleared once consumed.
    var pendingReadingScrollBookOrder: Int?

    let reader: BibleReaderViewModel
    let navigation: BibleNavigationViewModel

    init(reader: BibleReaderViewModel, navigation: BibleNavigationViewModel) {
        self.reader = reader
        self.navigation = navigation
    }

    /// Moves this window's reader to a position and shows the reader tab. The tab switches
    /// only after the selection is applied, so the reader's `onChange(selectedTab)`
    /// refreshes stripes for the new chapter, not the old.
    func showReader(versionCode: String? = nil, bookCode: String, chapter: Int, verse: Int) async {
        await reader.applyBibleSelectionAsync(
            versionCode: versionCode,
            bookCode: bookCode,
            chapterNum: chapter,
            verseNum: verse
        )
        reader.navigatedVerseNum = verse
        selectedTab = .bibleReader
        reader.bibleNavigationUpdateTrigger.toggle()
    }
}
