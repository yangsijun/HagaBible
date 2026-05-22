//
//  ReadingChecklistViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class ReadingChecklistViewModel {
    /// All 66 books (name + chapter count) of the resolved bible version.
    var books: [BibleBook] = []
    /// bookCode → set of chapters marked read. Keyed by the version-independent
    /// book_code (the sync identity), not book_order.
    var readChapters: [String: Set<Int>] = [:]
    var isLoading: Bool = false

    /// Version whose book list is currently loaded. Book names are
    /// version-specific (reading marks are not), so a version change must refetch
    /// the list — e.g. "창세기" (NKRV) vs "Genesis" (WEBBE).
    private var loadedVersionCode: String?

    private let appState: AppState
    private let readingMarkRepository: any ReadingMarkRepository
    private let bibleRepository: any BibleRepository

    init(
        appState: AppState,
        readingMarkRepository: any ReadingMarkRepository,
        bibleRepository: any BibleRepository
    ) {
        self.appState = appState
        self.readingMarkRepository = readingMarkRepository
        self.bibleRepository = bibleRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let versionCode = await resolveVersionCode() else {
            books = []
            readChapters = [:]
            loadedVersionCode = nil
            return
        }
        do {
            books = try await bibleRepository.fetchBibleBookList(versionCode: versionCode)
            loadedVersionCode = versionCode
        } catch {
            Logger.repository.error("ReadingChecklist book list load failed: \(error.localizedDescription)")
            books = []
        }
        await loadReadMarks()
    }

    /// Reloads when the reader's resolved version changed so book names follow
    /// the current version. No-op when the version is unchanged.
    func reloadIfVersionChanged() async {
        let versionCode = await resolveVersionCode()
        if versionCode != loadedVersionCode {
            await load()
        }
    }

    /// Prefer the reader's current version if it's downloaded, else the first
    /// downloaded version — the checklist needs a downloaded version's book list.
    private func resolveVersionCode() async -> String? {
        do {
            let versions = try await bibleRepository.fetchBibleVersionList()
            let downloaded = versions.filter { $0.isDownloaded }
            if let current = appState.bibleReaderState.bibleVersion?.versionCode,
               downloaded.contains(where: { $0.versionCode == current }) {
                return current
            }
            return downloaded.first?.versionCode
        } catch {
            return appState.bibleReaderState.bibleVersion?.versionCode
        }
    }

    private func loadReadMarks() async {
        do {
            let marks = try await readingMarkRepository.fetchAll()
            var dict: [String: Set<Int>] = [:]
            for mark in marks where mark.isRead {
                dict[mark.bookCode, default: []].insert(mark.chapter)
            }
            readChapters = dict
        } catch {
            Logger.repository.error("ReadingChecklist marks load failed: \(error.localizedDescription)")
            readChapters = [:]
        }
    }

    // MARK: - Queries

    func isRead(bookCode: String, chapter: Int) -> Bool {
        readChapters[bookCode]?.contains(chapter) ?? false
    }

    func readCount(forBook book: BibleBook) -> Int {
        readChapters[book.bookCode]?.count ?? 0
    }

    var overallRead: Int {
        books.reduce(0) { $0 + (readChapters[$1.bookCode]?.count ?? 0) }
    }

    var overallTotal: Int {
        books.reduce(0) { $0 + $1.totalChapters }
    }

    // MARK: - Mutation

    /// Optimistically toggles local state then persists; reverts on failure.
    func toggleRead(book: BibleBook, chapter: Int) {
        setRead(book: book, chapter: chapter, isRead: !isRead(bookCode: book.bookCode, chapter: chapter))
    }

    /// Sets a chapter to an explicit read state and persists immediately (single tap).
    /// Optimistic; no-op if already in the desired state; reverts on failure.
    func setRead(book: BibleBook, chapter: Int, isRead: Bool) {
        guard self.isRead(bookCode: book.bookCode, chapter: chapter) != isRead else { return }
        applyLocal(bookCode: book.bookCode, chapter: chapter, isRead: isRead)
        Task {
            do {
                try await readingMarkRepository.setRead(
                    bookCode: book.bookCode, bookOrder: book.bookOrder, chapter: chapter, isRead: isRead
                )
            } catch {
                Logger.repository.error("ReadingChecklist set failed: \(error.localizedDescription)")
                await loadReadMarks()  // revert to persisted truth
            }
        }
    }

    // MARK: - Drag-paint

    /// In-memory only (no DB): updates the live preview while a range drag grows
    /// or shrinks. Persist the final selection with `persistDragSelection` on release.
    func previewSetRead(bookCode: String, chapter: Int, isRead: Bool) {
        applyLocal(bookCode: bookCode, chapter: chapter, isRead: isRead)
    }

    /// Persists the final drag range in one atomic transaction. Pass only chapters
    /// whose state actually changed (the caller knows each cell's pre-drag state);
    /// chapters dropped from the range mid-drag were preview-only and need no write.
    func persistDragSelection(book: BibleBook, chapters: [Int], isRead: Bool) {
        guard !chapters.isEmpty else { return }
        Task {
            do {
                try await readingMarkRepository.setRead(
                    bookCode: book.bookCode, bookOrder: book.bookOrder, chapters: chapters, isRead: isRead
                )
            } catch {
                Logger.repository.error("ReadingChecklist drag persist failed: \(error.localizedDescription)")
                await loadReadMarks()  // revert to persisted truth
            }
        }
    }

    /// Clears every read mark (all chapters unread). Optimistic; reverts on failure.
    func resetAll() {
        readChapters = [:]
        Task {
            do {
                try await readingMarkRepository.resetAll()
            } catch {
                Logger.repository.error("ReadingChecklist reset failed: \(error.localizedDescription)")
                await loadReadMarks()  // revert to persisted truth
            }
        }
    }

    private func applyLocal(bookCode: String, chapter: Int, isRead: Bool) {
        if isRead {
            readChapters[bookCode, default: []].insert(chapter)
        } else {
            readChapters[bookCode]?.remove(chapter)
        }
    }
}
