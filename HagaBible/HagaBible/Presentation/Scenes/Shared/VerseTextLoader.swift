//
//  VerseTextLoader.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import Foundation
import OSLog

/// Loads verse text for bookmarks, resolving which Bible version to read from.
/// Shared by the bookmarks list (batch) and the add/edit form (single range).
@MainActor
struct VerseTextLoader {
    var appState: AppState = DIContainer.shared.resolve(type: AppState.self)
    var bibleRepository: any BibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)

    /// Prefer the version the user is currently reading; fall back to the first
    /// downloaded version only when no reading version is set.
    func resolveVersionCode() async throws -> String? {
        if let current = appState.bibleReaderState.bibleVersion?.versionCode {
            return current
        }
        let versions = try await bibleRepository.fetchBibleVersionList()
        return versions.first(where: { $0.isDownloaded })?.versionCode
    }

    /// Loads the combined verse text and resolved book name for a single range.
    func loadVerseText(bookCode: String, chapter: Int, startVerse: Int, endVerse: Int) async -> (bookName: String?, text: String)? {
        do {
            guard let versionCode = try await resolveVersionCode() else { return nil }
            let verses = try await bibleRepository.fetchBibleVerseList(
                versionCode: versionCode,
                bookCode: bookCode,
                chapter: chapter
            )
            let text = verses.combinedText(startVerse: startVerse, endVerse: endVerse)
            return (bookName: verses.first?.bookName, text: text)
        } catch {
            Logger.repository.warning("VerseTextLoader: failed to load verse text: \(error.localizedDescription)")
            return nil
        }
    }

    /// Batch-loads combined verse text per bookmark, caching verses by chapter.
    func loadVerseTexts(for bookmarks: [Bookmark]) async -> [UUID: String] {
        guard !bookmarks.isEmpty else { return [:] }
        let versionCode: String?
        do {
            versionCode = try await resolveVersionCode()
        } catch {
            Logger.repository.warning("VerseTextLoader: failed to resolve version: \(error.localizedDescription)")
            return [:]
        }
        guard let versionCode else { return [:] }

        var chapterCache: [String: [BibleVerse]] = [:]
        var texts: [UUID: String] = [:]
        for bookmark in bookmarks {
            let key = "\(bookmark.bookCode)-\(bookmark.chapter)"
            let verses: [BibleVerse]
            if let cached = chapterCache[key] {
                verses = cached
            } else {
                verses = (try? await bibleRepository.fetchBibleVerseList(
                    versionCode: versionCode,
                    bookCode: bookmark.bookCode,
                    chapter: bookmark.chapter
                )) ?? []
                chapterCache[key] = verses
            }
            let combined = verses.combinedText(startVerse: bookmark.startVerse, endVerse: bookmark.endVerse)
            if !combined.isEmpty {
                texts[bookmark.id] = combined
            }
        }
        return texts
    }
}
