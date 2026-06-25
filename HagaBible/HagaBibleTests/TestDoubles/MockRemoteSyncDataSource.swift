//
//  MockRemoteSyncDataSource.swift
//  HagaBibleTests
//
//  In-memory stand-in for the Supabase remote. Models the two server-side
//  conflict keys faithfully: bookmarks key on `id`, reading marks key on the
//  natural (book_code, chapter) — single test user, so user_id is elided. `pull`
//  applies the same `updated_at > since` delta filter the real PostgREST query uses.
//

import Foundation
@testable import HagaBible

actor MockRemoteSyncDataSource: RemoteSyncDataSource {

    // Server state, keyed by each table's conflict key.
    private(set) var bookmarks: [String: BookmarkDTO] = [:]            // key: id
    private(set) var readingMarks: [String: ReadingMarkDTO] = [:]      // key: "book_code#chapter"

    private static func readingKey(_ dto: ReadingMarkDTO) -> String { "\(dto.bookCode)#\(dto.chapter)" }

    // MARK: - Test seeding / inspection

    func seed(bookmark: BookmarkDTO) { bookmarks[bookmark.id] = bookmark }
    func seed(readingMark: ReadingMarkDTO) { readingMarks[Self.readingKey(readingMark)] = readingMark }

    var bookmarkCount: Int { bookmarks.count }
    var readingMarkCount: Int { readingMarks.count }
    func bookmark(id: String) -> BookmarkDTO? { bookmarks[id] }
    func readingMark(bookCode: String, chapter: Int) -> ReadingMarkDTO? { readingMarks["\(bookCode)#\(chapter)"] }

    // MARK: - RemoteSyncDataSource

    func pushBookmarks(_ rows: [BookmarkDTO]) async throws {
        for row in rows {
            if let existing = bookmarks[row.id], existing.updatedAt > row.updatedAt { continue }
            bookmarks[row.id] = row
        }
    }

    func pushReadingMarks(_ rows: [ReadingMarkDTO]) async throws {
        // Last-write-wins on the natural key, mirroring UNIQUE(user_id, book_code, chapter).
        for row in rows {
            let key = Self.readingKey(row)
            if let existing = readingMarks[key], existing.updatedAt > row.updatedAt { continue }
            readingMarks[key] = row
        }
    }

    func pullBookmarks(since: Double) async throws -> [BookmarkDTO] {
        bookmarks.values.filter { $0.updatedAt > since }.sorted { $0.updatedAt < $1.updatedAt }
    }

    func pullReadingMarks(since: Double) async throws -> [ReadingMarkDTO] {
        readingMarks.values.filter { $0.updatedAt > since }.sorted { $0.updatedAt < $1.updatedAt }
    }
}
