//
//  BookmarksViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class BookmarksViewModel {
    var bookmarks: [Bookmark] = []
    var availableBookCodes: [String] = []
    var sortOrder: BookmarkSortOrder = .createdAtDesc
    var selectedColor: BookmarkColor?
    var selectedBookCode: String?
    var keyword: String = ""
    var verseTexts: [UUID: String] = [:]
    var bookNames: [UUID: String] = [:]

    /// True once the first load finishes. Lets the embedding view load on first
    /// appear only, instead of re-running the heavy reload on every segment switch.
    private(set) var hasLoaded = false

    /// Backed by shared AppState so a toggle here reflects live in the reader,
    /// not just after the bookmarks sheet is dismissed.
    var isBookmarkIndicatorEnabled: Bool {
        get { appState.bookmarkIndicatorEnabled }
        set { appState.bookmarkIndicatorEnabled = newValue }
    }

    private let appState: AppState
    private let bookmarkRepository: any BookmarkRepository
    private let bibleRepository: any BibleRepository
    private let verseTextLoader: VerseTextLoader
    private var bookNameIndex: [String: Set<String>] = [:]
    private var abbreviationCache: [String: String?] = [:]

    init(
        appState: AppState,
        bookmarkRepository: any BookmarkRepository,
        bibleRepository: any BibleRepository
    ) {
        self.appState = appState
        self.bookmarkRepository = bookmarkRepository
        self.bibleRepository = bibleRepository
        self.verseTextLoader = VerseTextLoader(appState: appState, bibleRepository: bibleRepository)
    }

    var hasActiveFilters: Bool {
        selectedColor != nil || selectedBookCode != nil || !keyword.isEmpty
    }

    func refresh() async {
        bookNameIndex = [:]
        abbreviationCache = [:]
        await load()
    }

    func load() async {
        if bookNameIndex.isEmpty {
            await loadBookNameIndex()
        }
        do {
            let all = try await bookmarkRepository.fetchAll(sortedBy: sortOrder)
            availableBookCodes = Array(NSOrderedSet(array: all.map { $0.bookCode })) as? [String] ?? []

            let base: [Bookmark]
            if selectedColor != nil || selectedBookCode != nil {
                base = try await bookmarkRepository.fetchFiltered(
                    color: selectedColor,
                    bookCode: selectedBookCode,
                    keyword: nil
                )
            } else {
                base = all
            }

            if keyword.isEmpty {
                bookmarks = base
            } else {
                let resolved = await resolveKeyword(keyword)
                bookmarks = base.filter { matchesKeyword($0, keyword: keyword, resolved: resolved) }
            }
            await preloadVerseTexts(for: bookmarks)
        } catch {
            Logger.repository.error("BookmarksViewModel load error: \(error.localizedDescription)")
            bookmarks = []
            verseTexts = [:]
            bookNames = [:]
        }
        hasLoaded = true
    }

    private func preloadVerseTexts(for bookmarks: [Bookmark]) async {
        let loaded = await verseTextLoader.loadVerseTexts(for: bookmarks)
        verseTexts = loaded.compactMapValues { $0.text.isEmpty ? nil : $0.text }
        bookNames = loaded.compactMapValues { $0.bookName }
    }

    /// Display reference uses the book name from the current reading version
    /// (e.g. "Psalm"/"시편"), falling back to the raw book code if unresolved.
    func displayBookName(for bookmark: Bookmark) -> String {
        bookNames[bookmark.id] ?? bookmark.bookCode
    }

    private func loadBookNameIndex() async {
        do {
            let versions = try await bibleRepository.fetchBibleVersionList()
            var index: [String: Set<String>] = [:]
            for version in versions where version.isDownloaded {
                do {
                    let books = try await bibleRepository.fetchBibleBookList(versionCode: version.versionCode)
                    for book in books {
                        index[book.bookCode, default: []].insert(book.bookName)
                    }
                } catch {
                    Logger.repository.warning("BookmarksViewModel: failed to load books for \(version.versionCode): \(error.localizedDescription)")
                }
            }
            bookNameIndex = index
        } catch {
            Logger.repository.warning("BookmarksViewModel: failed to load bible versions: \(error.localizedDescription)")
        }
    }

    private struct ResolvedKeyword {
        let bookCode: String?
        let chapter: Int?
        let verse: Int?
    }

    private func resolveBookCodeSync(_ parsedBook: String) -> String? {
        let trimmed = parsedBook.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        if bookNameIndex.keys.contains(upper) {
            return upper
        }
        let lower = trimmed.lowercased()
        for (code, names) in bookNameIndex {
            if names.contains(where: { $0.lowercased() == lower }) {
                return code
            }
        }
        return nil
    }

    private func resolveBookCodeViaAbbreviation(_ abbreviation: String) async -> String? {
        let trimmed = abbreviation.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let cached = abbreviationCache[trimmed] {
            return cached
        }
        var resolved: String? = nil
        do {
            let versions = try await bibleRepository.fetchBibleVersionList()
            for version in versions where version.isDownloaded {
                if let code = try? await bibleRepository.findBookCodeByAbbreviation(
                    versionCode: version.versionCode,
                    abbreviation: trimmed
                ) {
                    resolved = code
                    break
                }
            }
        } catch {
            Logger.repository.warning("BookmarksViewModel: abbreviation resolution failed: \(error.localizedDescription)")
        }
        abbreviationCache[trimmed] = resolved
        return resolved
    }

    private func resolveKeyword(_ keyword: String) async -> ResolvedKeyword {
        let parsed = BibleReferenceParser.parse(keyword)
        let bookCode: String?
        if let sync = resolveBookCodeSync(parsed.book) {
            bookCode = sync
        } else {
            bookCode = await resolveBookCodeViaAbbreviation(parsed.book)
        }
        return ResolvedKeyword(bookCode: bookCode, chapter: parsed.chapter, verse: parsed.verse)
    }

    private func matchesKeyword(_ bookmark: Bookmark, keyword: String, resolved: ResolvedKeyword) -> Bool {
        if let notes = bookmark.notes, notes.lowercased().contains(keyword.lowercased()) {
            return true
        }
        guard let bookCode = resolved.bookCode, bookCode == bookmark.bookCode else {
            return false
        }
        if let chapter = resolved.chapter, bookmark.chapter != chapter {
            return false
        }
        if let verse = resolved.verse {
            return bookmark.startVerse <= verse && verse <= bookmark.endVerse
        }
        return true
    }

    func delete(id: UUID) async {
        do {
            try await bookmarkRepository.delete(id: id)
            await load()
        } catch {
            Logger.repository.error("BookmarksViewModel delete error: \(error.localizedDescription)")
        }
    }

    func update(_ bookmark: Bookmark) async {
        do {
            try await bookmarkRepository.update(bookmark)
            await load()
        } catch {
            Logger.repository.error("BookmarksViewModel update error: \(error.localizedDescription)")
        }
    }

    func toggleSort() {
        sortOrder = sortOrder == .createdAtDesc ? .biblicalOrder : .createdAtDesc
        Task { await load() }
    }

    func applyFilter(color: BookmarkColor?, bookCode: String?, keyword: String) {
        selectedColor = color
        selectedBookCode = bookCode
        self.keyword = keyword
        Task { await load() }
    }

    func toggleIndicator() {
        isBookmarkIndicatorEnabled.toggle()
    }
}
