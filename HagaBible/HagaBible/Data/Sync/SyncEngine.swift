//
//  SyncEngine.swift
//  HagaBible
//
//  Delta + Last-Write-Wins sync over the local GRDB user-data store. The engine
//  is the orchestration layer; the network lives behind `RemoteSyncDataSource`,
//  and the watermark lives in the local `sync_state` table — so the whole engine
//  is unit-testable with a temp pool and an in-memory remote double.
//
//  Cycle:
//    1. pushPending — every row with needs_sync = 1 is uploaded, then cleared.
//    2. pull        — rows newer than the per-table watermark are merged in (LWW),
//                     and the watermark advances to the newest row seen.
//
//  Conflict keys differ by table: bookmarks merge on `id` (many per chapter),
//  reading marks merge on the natural key (book_code, chapter) so the same
//  chapter marked offline on two devices converges to one row.
//

import Foundation
import GRDB
import OSLog

actor SyncEngine {
    private let pool: DatabasePool
    private let remote: RemoteSyncDataSource

    init(pool: DatabasePool, remote: RemoteSyncDataSource) {
        self.pool = pool
        self.remote = remote
    }

    // MARK: - Top-level cycle

    /// Push local changes, then pull remote changes. Push first so freshly-created
    /// local rows reach the server before we fold in whatever is already there.
    func sync(userId: String) async throws {
        try await pushPending(userId: userId)
        try await pull()
    }

    // MARK: - Push

    func pushPending(userId: String) async throws {
        try await pushPendingBookmarks(userId: userId)
        try await pushPendingReadingMarks(userId: userId)
    }

    private func pushPendingBookmarks(userId: String) async throws {
        let dirty = try await pool.read { db in
            try BookmarkRecord.fetchAll(db, sql: "SELECT * FROM bookmarks WHERE needs_sync = 1")
        }
        guard !dirty.isEmpty else { return }

        try await remote.pushBookmarks(dirty.map { BookmarkDTO(record: $0, userId: userId) })

        // Clear the dirty flag only for rows that did not change while in flight
        // (guarded by updated_at). Stamp user_id so the local row is scoped too.
        try await pool.write { db in
            for row in dirty {
                try db.execute(
                    sql: "UPDATE bookmarks SET needs_sync = 0, user_id = ? WHERE id = ? AND updated_at = ?",
                    arguments: [userId, row.id, row.updatedAt]
                )
            }
        }
        Logger.repository.debug("Sync pushed \(dirty.count) bookmark(s)")
    }

    private func pushPendingReadingMarks(userId: String) async throws {
        let dirty = try await pool.read { db in
            try ReadingMarkRecord.fetchAll(db, sql: "SELECT * FROM reading_marks WHERE needs_sync = 1")
        }
        guard !dirty.isEmpty else { return }

        try await remote.pushReadingMarks(dirty.map { ReadingMarkDTO(record: $0, userId: userId) })

        try await pool.write { db in
            for row in dirty {
                try db.execute(
                    sql: "UPDATE reading_marks SET needs_sync = 0, user_id = ? WHERE id = ? AND updated_at = ?",
                    arguments: [userId, row.id, row.updatedAt]
                )
            }
        }
        Logger.repository.debug("Sync pushed \(dirty.count) reading mark(s)")
    }

    // MARK: - Pull

    func pull() async throws {
        try await pullBookmarks()
        try await pullReadingMarks()
    }

    private func pullBookmarks() async throws {
        let since = try await watermark(for: "bookmarks")
        let rows = try await remote.pullBookmarks(since: since)
        guard !rows.isEmpty else { return }

        try await pool.write { db in
            for dto in rows {
                try db.execute(
                    sql: """
                        INSERT INTO bookmarks
                            (id, book_code, book_order, chapter, start_verse, end_verse,
                             color, notes, created_at, updated_at, deleted_at, user_id, needs_sync)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                        ON CONFLICT(id) DO UPDATE SET
                            book_code = excluded.book_code,
                            book_order = excluded.book_order,
                            chapter = excluded.chapter,
                            start_verse = excluded.start_verse,
                            end_verse = excluded.end_verse,
                            color = excluded.color,
                            notes = excluded.notes,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at,
                            deleted_at = excluded.deleted_at,
                            user_id = excluded.user_id,
                            needs_sync = 0
                        WHERE excluded.updated_at >= bookmarks.updated_at
                        """,
                    arguments: [
                        dto.id, dto.bookCode, dto.bookOrder, dto.chapter,
                        dto.startVerse, dto.endVerse, dto.color, dto.notes,
                        dto.createdAt, dto.updatedAt, dto.deletedAt, dto.userId
                    ]
                )
            }
        }

        let newWatermark = rows.map(\.updatedAt).max() ?? since
        try await setWatermark(newWatermark, for: "bookmarks")
        Logger.repository.debug("Sync pulled \(rows.count) bookmark(s)")
    }

    private func pullReadingMarks() async throws {
        let since = try await watermark(for: "reading_marks")
        let rows = try await remote.pullReadingMarks(since: since)
        guard !rows.isEmpty else { return }

        try await pool.write { db in
            for dto in rows {
                try db.execute(
                    sql: """
                        INSERT INTO reading_marks
                            (id, book_code, book_order, chapter, is_read,
                             created_at, updated_at, deleted_at, user_id, needs_sync)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                        ON CONFLICT(book_code, chapter) DO UPDATE SET
                            -- id is intentionally excluded: the local id must stay stable
                            -- so pushPendingReadingMarks' WHERE id=? clear-guard matches.
                            book_order = excluded.book_order,
                            is_read = excluded.is_read,
                            created_at = excluded.created_at,
                            updated_at = excluded.updated_at,
                            deleted_at = excluded.deleted_at,
                            user_id = excluded.user_id,
                            needs_sync = 0
                        WHERE excluded.updated_at >= reading_marks.updated_at
                        """,
                    arguments: [
                        dto.id, dto.bookCode, dto.bookOrder, dto.chapter, dto.isRead,
                        dto.createdAt, dto.updatedAt, dto.deletedAt, dto.userId
                    ]
                )
            }
        }

        let newWatermark = rows.map(\.updatedAt).max() ?? since
        try await setWatermark(newWatermark, for: "reading_marks")
        Logger.repository.debug("Sync pulled \(rows.count) reading mark(s)")
    }

    // MARK: - Account lifecycle

    /// Wipe local user data and the watermark. Called when a *different* account
    /// signs in on the same device, so the second account never sees — or re-
    /// uploads under its own id — the previous account's rows. The next sync then
    /// pulls the new account's full history from a clean slate.
    func clearLocalUserData() async throws {
        try await pool.write { db in
            try db.execute(sql: "DELETE FROM bookmarks")
            try db.execute(sql: "DELETE FROM reading_marks")
            try db.execute(sql: "DELETE FROM sync_state")
        }
        Logger.repository.debug("Sync cleared local user data on account change")
    }

    // MARK: - Watermark (sync_state table)

    private func watermark(for table: String) async throws -> Double {
        try await pool.read { db in
            try Double.fetchOne(
                db,
                sql: "SELECT last_pulled_at FROM sync_state WHERE table_name = ?",
                arguments: [table]
            ) ?? 0
        }
    }

    private func setWatermark(_ value: Double, for table: String) async throws {
        try await pool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO sync_state (table_name, last_pulled_at) VALUES (?, ?)
                    ON CONFLICT(table_name) DO UPDATE SET last_pulled_at = excluded.last_pulled_at
                    WHERE excluded.last_pulled_at > sync_state.last_pulled_at
                    """,
                arguments: [table, value]
            )
        }
    }
}
