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
    private let bibleActionService: BibleActionService

    /// This window's own position. Each window has its own reader, so the position is
    /// stored here, not in `AppState`; every change is also written through to
    /// `appState.bibleReaderState`, which is the app-wide "last read" position: it is what
    /// gets persisted, what a new window opens at, and what App Intents / recordings read.
    private var state = BibleReaderState()

    var bibleVersion: BibleVersion? {
        get { state.bibleVersion }
        set {
            state.bibleVersion = newValue
            appState.bibleReaderState.bibleVersion = newValue
        }
    }
    var bibleBook: BibleBook? {
        get { state.bibleBook }
        set {
            state.bibleBook = newValue
            appState.bibleReaderState.bibleBook = newValue
        }
    }
    var bibleChapter: BibleChapter? {
        get { state.bibleChapter }
        set {
            state.bibleChapter = newValue
            appState.bibleReaderState.bibleChapter = newValue
        }
    }
    var bibleVerse: BibleVerse? {
        get { state.bibleVerse }
        set {
            state.bibleVerse = newValue
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
    /// Comparison verses for the current book/chapter (kept for export, which needs
    /// each verse's own book name). Stays in sync with `compareTextByVerse`.
    var compareVerseList: [BibleVerse] = []

    /// The resolved comparison version, if one is selected and available.
    var compareVersion: BibleVersion? {
        guard let compareVersionCode else { return nil }
        return availableVersions.first { $0.versionCode == compareVersionCode }
    }

    /// Whether translation comparison is currently active.
    var isComparisonOn: Bool { compareVersion != nil }

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

    /// `bibleActionService` defaults to the container's; tests pass their own so they never
    /// touch `DIContainer.shared` (its dictionary isn't thread-safe across parallel suites).
    init(
        appState: AppState,
        bibleRepository: BibleRepository,
        bookmarkRepository: BookmarkRepository,
        bibleActionService: BibleActionService? = nil
    ) {
        self.appState = appState

        self.bibleRepository = bibleRepository
        self.bookmarkRepository = bookmarkRepository
        self.bibleActionService = bibleActionService ?? DIContainer.shared.resolve(type: BibleActionService.self)

        // The app-wide last-read position wins (a new window opens where the user is reading);
        // the disk-restored position seeds a cold launch; the constants are the ultimate fallback.
        let restored = appState.restoredReaderPosition
        self.versionCode = appState.bibleReaderState.bibleVersion?.versionCode ?? restored?.versionCode ?? "WEBBE"
        self.bookCode = appState.bibleReaderState.bibleBook?.bookCode ?? restored?.bookCode ?? "GEN"
        self.chapterNum = appState.bibleReaderState.bibleChapter?.chapter ?? restored?.chapter ?? 1
        self.verseNum = appState.bibleReaderState.bibleVerse?.verse ?? restored?.verse ?? 1
        // No fetch here: the catalog is still empty, so resolving would set every entity to
        // nil and write those nils through to `appState.bibleReaderState`, and the next new
        // window would open at the launch-time position. The reader view loads on appear.
    }

    /// This window's position as plain identifiers, for per-scene state restoration.
    var position: PersistedReaderPosition {
        PersistedReaderPosition(versionCode: versionCode, bookCode: bookCode, chapter: chapterNum, verse: verseNum)
    }

    /// Puts a recreated window back where it was. Only the identifiers change, before the
    /// reader view loads them, so nothing is written through to the app-wide position.
    func restore(_ position: PersistedReaderPosition) {
        versionCode = position.versionCode ?? versionCode
        bookCode = position.bookCode ?? bookCode
        chapterNum = position.chapter ?? chapterNum
        verseNum = position.verse ?? verseNum
    }
    
    func fetchAvailableVersions() async {
        do {
            availableVersions = try await bibleRepository.fetchBibleVersionList()
        } catch {
            Logger.repository.error("Error fetching available versions: \(error.localizedDescription)")
        }
    }
    
    /// Set when the reader had to open a different version than the one it wanted
    /// because that file is not on the device. The view shows it once as a banner and
    /// clears it.
    var versionFallbackNotice: String?

    /// Resolves `versionCode` against the catalog. A version whose file is missing is
    /// swapped for a readable one (same language first) so the page is never blank; the
    /// swap is persisted through `versionCode`/`bibleVersion` so it does not flip back on
    /// the next fetch. Nothing changes while the catalog is still empty.
    func fetchBibleVersion() async {
        let resolved = BibleVersionFallback.resolve(preferred: versionCode, among: availableVersions)
        if let resolved, resolved.versionCode != versionCode {
            let wantedName = availableVersions.first { $0.versionCode == versionCode }?.versionName ?? versionCode
            Logger.repository.notice("\(self.versionCode) is not downloaded; opening \(resolved.versionCode) instead")
            versionFallbackNotice = String(localized: "\(wantedName) is not available. Showing \(resolved.versionName).")
            versionCode = resolved.versionCode
        }
        bibleVersion = resolved
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
            compareVerseList = []
            return
        }
        if code == versionCode {
            // The main version switched to match the comparison version; there is
            // nothing meaningful to compare, so disable comparison entirely.
            compareVersionCode = nil
            compareTextByVerse = [:]
            compareVerseList = []
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
            compareVerseList = verses
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
            compareVerseList = []
        }
    }

    enum VerseExportScope {
        case main      // 역본 A (the reader's current version)
        case compare   // 역본 B (the comparison version)
        case both      // 둘 다
    }

    /// Builds the copy/share text for a verse selection in the chosen scope.
    /// `startIndex`/`endIndex` are row indices (verse number = index + 1). A single
    /// version (`.main`/`.compare`) omits the version name; `.both` tags each block
    /// with the short version name (`versionShortName`, e.g. 개역개정/KJV) and separates
    /// them with a blank line. Missing blocks (e.g. a versification gap) are omitted.
    func makeExportText(startIndex: Int, endIndex: Int, scope: VerseExportScope) -> String {
        let startVerse = min(startIndex, endIndex) + 1
        let endVerse = max(startIndex, endIndex) + 1

        switch scope {
        case .main:
            return bibleActionService.makeVersionBlock(bibleVerseList, startVerse: startVerse, endVerse: endVerse, versionName: nil) ?? ""
        case .compare:
            return bibleActionService.makeVersionBlock(compareVerseList, startVerse: startVerse, endVerse: endVerse, versionName: nil) ?? ""
        case .both:
            let mainBlock = bibleActionService.makeVersionBlock(bibleVerseList, startVerse: startVerse, endVerse: endVerse, versionName: bibleVersion?.versionShortName)
            let compareBlock = bibleActionService.makeVersionBlock(compareVerseList, startVerse: startVerse, endVerse: endVerse, versionName: compareVersion?.versionShortName)
            return [mainBlock, compareBlock].compactMap { $0 }.joined(separator: "\n\n")
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

    // MARK: - Paged reading (Labs)

    /// The current chapter as the paged reader typesets it. The key comes from the loaded
    /// verses, not from `bookCode`/`chapterNum`: during a navigation those update one await
    /// ahead of the verse list, and keying on them would briefly present the old verses as
    /// the new chapter.
    var pagedChapterContent: ChapterContent {
        makePagedChapterContent(
            key: bibleVerseList.first.map { ChapterKey(versionCode: $0.versionCode, bookCode: $0.bookCode, chapter: $0.chapter) }
                ?? ChapterKey(versionCode: versionCode, bookCode: bookCode, chapter: chapterNum),
            verses: bibleVerseList,
            compareTextByVerse: compareVersion != nil ? compareTextByVerse : [:]
        )
    }

    /// The chapter before/after the given one in reading order, crossing book boundaries;
    /// `nil` at the very start or end of the Bible.
    func adjacentChapter(bookCode: String, chapter: Int, forward: Bool) -> (bookCode: String, chapter: Int)? {
        guard let index = bibleBookList.firstIndex(where: { $0.bookCode == bookCode }) else { return nil }
        if forward {
            if chapter < bibleBookList[index].totalChapters { return (bookCode, chapter + 1) }
            guard index + 1 < bibleBookList.count else { return nil }
            return (bibleBookList[index + 1].bookCode, 1)
        } else {
            if chapter > 1 { return (bookCode, chapter - 1) }
            guard index > 0 else { return nil }
            return (bibleBookList[index - 1].bookCode, bibleBookList[index - 1].totalChapters)
        }
    }

    /// Loads a chapter of the current version (plus its comparison text when comparison is
    /// on) for the paged reader to prefetch, without touching the reader's own position.
    func fetchPagedChapterContent(bookCode: String, chapter: Int) async -> ChapterContent? {
        do {
            let verses = try await bibleRepository.fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapter: chapter)
            var compare: [Int: String] = [:]
            if let code = compareVersionCode, code != versionCode {
                let compareVerses = try await bibleRepository.fetchBibleVerseList(versionCode: code, bookCode: bookCode, chapter: chapter)
                compare = Dictionary(
                    compareVerses.compactMap { verse in verse.verseText.map { (verse.verse, $0) } },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            return makePagedChapterContent(
                key: ChapterKey(versionCode: versionCode, bookCode: bookCode, chapter: chapter),
                verses: verses,
                compareTextByVerse: compare
            )
        } catch {
            Logger.repository.error("Error prefetching chapter for paged reading: \(error.localizedDescription)")
            return nil
        }
    }

    private func makePagedChapterContent(key: ChapterKey, verses: [BibleVerse], compareTextByVerse: [Int: String]) -> ChapterContent {
        ChapterContent(key: key, verses: verses, compareTextByVerse: compareTextByVerse)
    }
}
