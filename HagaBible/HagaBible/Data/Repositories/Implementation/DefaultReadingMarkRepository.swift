//
//  DefaultReadingMarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import Foundation
import GRDB
import OSLog

final class DefaultReadingMarkRepository: ReadingMarkRepository {

    // MARK: - Fetch

    func fetchAll() async throws -> [ReadingMark] {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return []
        }
        let sql = "SELECT * FROM reading_marks WHERE deleted_at IS NULL ORDER BY book_order ASC, chapter ASC"
        return try await pool.read { db in
            let records = try ReadingMarkRecord.fetchAll(db, sql: sql, arguments: [])
            return records.map { self.toEntity($0) }
        }
    }

    // MARK: - Upsert

    func setRead(bookCode: String, bookOrder: Int, chapter: Int, isRead: Bool) async throws {
        try await setRead(bookCode: bookCode, bookOrder: bookOrder, chapters: [chapter], isRead: isRead)
    }

    func setRead(bookCode: String, bookOrder: Int, chapters: [Int], isRead: Bool) async throws {
        guard !chapters.isEmpty,
              let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return
        }
        do {
            let now = Date().timeIntervalSince1970
            let readValue = isRead ? 1 : 0
            // Single transaction for the whole batch — a range drag is one logical
            // operation, so it must be atomic (all or nothing).
            try await pool.write { db in
                for chapter in chapters {
                    try Self.upsert(
                        db,
                        bookCode: bookCode,
                        bookOrder: bookOrder,
                        chapter: chapter,
                        readValue: readValue,
                        now: now
                    )
                }
            }
            Logger.repository.debug("ReadingMark set: \(bookCode) chapters \(chapters) read=\(isRead)")
        } catch {
            Logger.repository.error("ReadingMark write failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// One row per (book_code, chapter). `ON CONFLICT` makes this resilient to a
    /// tombstoned row: the sync layer can soft-delete a mark, and a later re-mark
    /// resurrects it (`deleted_at = NULL`) instead of hitting the UNIQUE index with
    /// an INSERT. The `WHERE` on the update skips no-op writes so an unchanged value
    /// doesn't bump `updated_at` and generate a spurious sync delta. `created_at`,
    /// `id`, and `book_order` are preserved on conflict.
    nonisolated private static func upsert(
        _ db: Database,
        bookCode: String,
        bookOrder: Int,
        chapter: Int,
        readValue: Int,
        now: Double
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO reading_marks
                    (id, book_code, book_order, chapter, is_read, created_at, updated_at, deleted_at, user_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL)
                ON CONFLICT(book_code, chapter) DO UPDATE SET
                    is_read = excluded.is_read,
                    updated_at = excluded.updated_at,
                    deleted_at = NULL
                WHERE reading_marks.is_read <> excluded.is_read
                   OR reading_marks.deleted_at IS NOT NULL
                """,
            arguments: [UUID().uuidString, bookCode, bookOrder, chapter, readValue, now, now]
        )
    }

    // MARK: - Reset

    func resetAll() async throws {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return
        }
        do {
            // Set every read chapter unread. Rows are kept (not deleted) so a later
            // re-mark reuses them — the (book_code, chapter) index is UNIQUE regardless
            // of deleted_at, so a tombstone-then-reinsert would collide. `updated_at`
            // is bumped only on changed rows for delta sync.
            let now = Date().timeIntervalSince1970
            try await pool.write { db in
                try db.execute(
                    sql: "UPDATE reading_marks SET is_read = 0, updated_at = ? WHERE is_read = 1 AND deleted_at IS NULL",
                    arguments: [now]
                )
            }
            Logger.repository.debug("ReadingMark reset: all chapters set unread")
        } catch {
            Logger.repository.error("ReadingMark reset failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Mapping Helpers

    nonisolated private func toEntity(_ record: ReadingMarkRecord) -> ReadingMark {
        ReadingMark(
            id: UUID(uuidString: record.id) ?? UUID(),
            bookCode: record.bookCode,
            bookOrder: record.bookOrder,
            chapter: record.chapter,
            isRead: record.isRead != 0,
            createdAt: Date(timeIntervalSince1970: record.createdAt),
            updatedAt: Date(timeIntervalSince1970: record.updatedAt)
        )
    }
}
