//
//  BibleReaderViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
class BibleReaderViewModel {
    private let appState: AppState
    
    var isLoading: Bool = false
    var isLoadingSuccess: Bool?
    
    var bibleRepository: BibleRepository
    private let bookmarkRepository: BookmarkRepository

    var bibleVersion: BibleVersion? {
        get {
            appState.bibleReaderState.bibleVersion
        }
        set {
            appState.bibleReaderState.bibleVersion = newValue
        }
    }
    var bibleBook: BibleBook? {
        get {
            appState.bibleReaderState.bibleBook
        }
        set {
            appState.bibleReaderState.bibleBook = newValue
        }
    }
    var bibleChapter: BibleChapter? {
        get {
            appState.bibleReaderState.bibleChapter
        }
        set {
            appState.bibleReaderState.bibleChapter = newValue
        }
    }
    var bibleVerse: BibleVerse? {
        get {
            appState.bibleReaderState.bibleVerse
        }
        set {
            appState.bibleReaderState.bibleVerse = newValue
        }
    }
    
    var availableVersions: [BibleVersion] = []
    var bibleBookList: [BibleBook] = []
    var bibleChapterList: [BibleChapter] = []
    var bibleVerseList: [BibleVerse] = []
    
    var versionCode: String
    var bookCode: String
    var chapterNum: Int
    var verseNum: Int
    
    var navigatedVerseNum: Int?

    // MARK: - Translation comparison (역본 대조)

    /// Version code shown beneath each verse for side-by-side comparison;
    /// `nil` means comparison is off. Persisted across launches.
    var compareVersionCode: String? = ComparePreferences.compareVersionCode {
        didSet { ComparePreferences.compareVersionCode = compareVersionCode }
    }
    /// Comparison verses for the current book/chapter, keyed by verse number.
    var compareTextByVerse: [Int: String] = [:]

    /// The resolved comparison version, if one is selected and available.
    var compareVersion: BibleVersion? {
        guard let compareVersionCode else { return nil }
        return availableVersions.first { $0.versionCode == compareVersionCode }
    }

    /// Versions selectable for comparison: downloaded and not the main version.
    var comparableVersions: [BibleVersion] {
        availableVersions.filter { $0.isDownloaded && $0.versionCode != versionCode }
    }

    var bookmarksForCurrentChapter: [Bookmark] = [] {
        didSet {
            bookmarkStripesPerVerse = BookmarkStripeComputer.computeStripes(from: bookmarksForCurrentChapter)
        }
    }
    var bookmarkStripesPerVerse: [Int: [BookmarkStripe?]] = [:]

    /// Backed by shared AppState so toggling it anywhere (e.g. the bookmarks
    /// sheet) updates the reader live, not just on sheet dismiss.
    var isBookmarkIndicatorEnabled: Bool {
        get { appState.bookmarkIndicatorEnabled }
        set { appState.bookmarkIndicatorEnabled = newValue }
    }

    init(appState: AppState, bibleRepository: BibleRepository, bookmarkRepository: BookmarkRepository) {
        self.appState = appState

        self.bibleRepository = bibleRepository
        self.bookmarkRepository = bookmarkRepository

        self.versionCode = appState.bibleReaderState.bibleVersion?.versionCode ?? "WEBBE"
        self.bookCode = appState.bibleReaderState.bibleBook?.bookCode ?? "GEN"
        self.chapterNum = appState.bibleReaderState.bibleChapter?.chapter ?? 1
        self.verseNum = appState.bibleReaderState.bibleVerse?.verse ?? 1
        
        applyBibleSelection(
            versionCode: versionCode,
            bookCode: bookCode,
            chapterNum: chapterNum,
            verseNum: verseNum
        )
    }
    
    func fetchAvailableVersions() async {
        do {
            availableVersions = try await bibleRepository.fetchBibleVersionList()
        } catch {
            Logger.repository.error("Error fetching available versions: \(error.localizedDescription)")
        }
    }
    
    func fetchBibleVersion() async {
        bibleVersion = availableVersions.first { $0.versionCode == versionCode }
        if let versionCode = bibleVersion?.versionCode {
            await fetchBibleBookList(versionCode: versionCode)
        }
    }
    
    func fetchBibleBookList(versionCode: String) async {
        do {
            bibleBookList = try await bibleRepository.fetchBibleBookList(versionCode: versionCode)
        } catch {
            Logger.repository.error("Error fetching books: \(error.localizedDescription)")
        }
    }
    
    func fetchBibleBook() async {
        bibleBook = bibleBookList.first { $0.bookCode == bookCode }
        if let bookCode = bibleBook?.bookCode {
            await fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
        }
    }
    
    func fetchBibleChapterList(versionCode: String, bookCode: String) async {
        do {
            bibleChapterList = try await bibleRepository.fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
        } catch {
            Logger.repository.error("Error fetching chapters: \(error.localizedDescription)")
        }
    }
    
    func fetchBibleChapter() async {
        bibleChapter = bibleChapterList.first { $0.chapter == chapterNum }
        if let chapterNum = bibleChapter?.chapter {
            await fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapterNum: chapterNum)
        }
    }
    
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapterNum: Int) async {
        do {
            bibleVerseList = try await bibleRepository.fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapter: chapterNum)
        } catch {
            Logger.repository.error("Error fetching verses: \(error.localizedDescription)")
        }
        await fetchBookmarksForCurrentChapter()
        await fetchCompareVerseList()
    }

    /// Selects (or clears, with `nil`) the comparison version and refreshes the
    /// comparison verses for the current chapter immediately.
    func setCompareVersion(_ code: String?) async {
        compareVersionCode = code
        await fetchCompareVerseList()
    }

    /// Loads the comparison version's verses for the current book/chapter and
    /// builds the verse-number → text map. Clears the map when comparison is off,
    /// and when the main version becomes the comparison version it turns the
    /// comparison off so the toolbar reflects reality. Stale results from a
    /// superseded selection (rapid chapter swipes or menu taps) are discarded.
    func fetchCompareVerseList() async {
        guard let code = compareVersionCode else {
            compareTextByVerse = [:]
            return
        }
        if code == versionCode {
            // The main version switched to match the comparison version; there is
            // nothing meaningful to compare, so disable comparison entirely.
            compareVersionCode = nil
            compareTextByVerse = [:]
            return
        }
        let expectedCode = code
        let expectedBook = bookCode
        let expectedChapter = chapterNum
        do {
            let verses = try await bibleRepository.fetchBibleVerseList(versionCode: code, bookCode: bookCode, chapter: chapterNum)
            // Drop the result if the selection moved on while we were fetching.
            guard compareVersionCode == expectedCode,
                  bookCode == expectedBook,
                  chapterNum == expectedChapter else { return }
            compareTextByVerse = Dictionary(
                verses.compactMap { verse in verse.verseText.map { (verse.verse, $0) } },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            Logger.repository.error("Error fetching comparison verses: \(error.localizedDescription)")
            guard compareVersionCode == expectedCode,
                  bookCode == expectedBook,
                  chapterNum == expectedChapter else { return }
            compareTextByVerse = [:]
        }
    }

    func fetchBookmarksForCurrentChapter() async {
        guard let bookOrder = bibleBook?.bookOrder else { return }
        do {
            bookmarksForCurrentChapter = try await bookmarkRepository.fetchForChapter(bookOrder: bookOrder, chapter: chapterNum)
        } catch {
            Logger.repository.error("Error fetching bookmarks for chapter: \(error.localizedDescription)")
            bookmarksForCurrentChapter = []
        }
    }
    
    func fetchBibleVerse() {
        bibleVerse = bibleVerseList.first(where: { $0.verse == verseNum })
    }
    
    func goToPreviousChapter() {
        Task { await goToPreviousChapterAsync() }
    }

    func goToPreviousChapterAsync() async {
        if chapterNum > 1 {
            await applyBibleSelectionAsync(
                chapterNum: chapterNum - 1,
                verseNum: 1
            )
            return
        }
        guard let currentBook = bibleBookList.first(where: { $0.bookCode == bookCode }),
              let index = bibleBookList.firstIndex(of: currentBook) else { return }
        if index == 0 { return }
        await applyBibleSelectionAsync(
            bookCode: bibleBookList[index - 1].bookCode,
            chapterNum: bibleBookList[index - 1].totalChapters,
            verseNum: 1
        )
    }

    func goToNextChapter() {
        Task { await goToNextChapterAsync() }
    }

    func goToNextChapterAsync() async {
        guard let lastChapter = bibleChapterList.last else { return }
        if chapterNum < lastChapter.chapter {
            await applyBibleSelectionAsync(
                chapterNum: chapterNum + 1,
                verseNum: 1
            )
            return
        }
        guard let currentBook = bibleBookList.first(where: { $0.bookCode == bookCode }),
              let index = bibleBookList.firstIndex(of: currentBook) else { return }
        if index == bibleBookList.count - 1 { return }
        await applyBibleSelectionAsync(
            bookCode: bibleBookList[index + 1].bookCode,
            chapterNum: 1,
            verseNum: 1
        )
    }

    func applyBibleSelection(
        versionCode: String? = nil,
        bookCode: String? = nil,
        chapterNum: Int? = nil,
        verseNum: Int? = nil
    ) {
        Task { await applyBibleSelectionAsync(versionCode: versionCode, bookCode: bookCode, chapterNum: chapterNum, verseNum: verseNum) }
    }

    func applyBibleSelectionAsync(
        versionCode: String? = nil,
        bookCode: String? = nil,
        chapterNum: Int? = nil,
        verseNum: Int? = nil
    ) async {
        if let versionCode = versionCode {
            self.versionCode = versionCode
            await fetchBibleVersion()
        }
        if let bookCode = bookCode {
            self.bookCode = bookCode
            await fetchBibleBook()
        }
        if let chapterNum = chapterNum {
            self.chapterNum = chapterNum
            await fetchBibleChapter()
        }
        if let verseNum = verseNum {
            self.verseNum = verseNum
            fetchBibleVerse()
        }
    }
    
    var bibleNavigationUpdateTrigger: Bool = false
}
