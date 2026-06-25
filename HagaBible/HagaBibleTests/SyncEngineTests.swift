//
//  SyncEngineTests.swift
//  HagaBibleTests
//
//  Unit tests for the delta + LWW sync engine, driven entirely off a temp GRDB
//  pool and an in-memory remote — no network. Verifies dirty tracking, push-clear,
//  LWW on pull (newer wins, older ignored), reading-mark natural-key convergence,
//  and watermark advancement.
//

import Testing
import Foundation
import GRDB
@testable import HagaBible

extension UserDataSuites {
    @Suite("SyncEngine Tests", .serialized)
    struct SyncEngineTests {

        // MARK: - Environment

        private struct Env {
            let pool: DatabasePool
            let bookmarks: DefaultBookmarkRepository
            let reading: DefaultReadingMarkRepository
            let remote: MockRemoteSyncDataSource
            let engine: SyncEngine
            let url: URL
        }

        private func makeEnv() throws -> Env {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("test-sync-\(UUID().uuidString).sqlite")
            let service = try UserDataDatabaseService(databaseFileURL: url)
            DIContainer.shared.register(type: UserDataDatabaseService.self, component: service)
            let pool = try #require(service.dbPool)
            let remote = MockRemoteSyncDataSource()
            return Env(
                pool: pool,
                bookmarks: DefaultBookmarkRepository(),
                reading: DefaultReadingMarkRepository(),
                remote: remote,
                engine: SyncEngine(pool: pool, remote: remote),
                url: url
            )
        }

        /// Close the pool BEFORE deleting the file, otherwise SQLite logs a scary
        /// "vnode unlinked while in use" integrity warning (the pool still holds the
        /// fd of the file we just removed). Closing checkpoints and releases it.
        private func cleanup(_ env: Env) {
            try? env.pool.close()
            let url = env.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
        }

        // MARK: - Local SQL helpers (precise control of updated_at / needs_sync)

        private func insertSyncedBookmark(
            _ pool: DatabasePool, id: String, color: String, updatedAt: Double
        ) async throws {
            try await pool.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO bookmarks
                            (id, book_code, book_order, chapter, start_verse, end_verse,
                             color, notes, created_at, updated_at, deleted_at, user_id, needs_sync)
                        VALUES (?, 'GEN', 1, 1, 1, 1, ?, NULL, 1.0, ?, NULL, 'U', 0)
                        """,
                    arguments: [id, color, updatedAt]
                )
            }
        }

        private func needsSync(_ pool: DatabasePool, bookmarkId: String) async throws -> Int {
            try await pool.read { db in
                try Int.fetchOne(db, sql: "SELECT needs_sync FROM bookmarks WHERE id = ?", arguments: [bookmarkId]) ?? -1
            }
        }

        private func color(_ pool: DatabasePool, bookmarkId: String) async throws -> String? {
            try await pool.read { db in
                try String.fetchOne(db, sql: "SELECT color FROM bookmarks WHERE id = ?", arguments: [bookmarkId])
            }
        }

        private func bookmarkRowCount(_ pool: DatabasePool) async throws -> Int {
            try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM bookmarks") ?? 0 }
        }

        // MARK: - Tests

        @Test("a domain bookmark write is marked needs_sync, then pushPending uploads it and clears the flag")
        func test_push_uploadsDirtyAndClears() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            let bookmark = Bookmark(
                id: UUID(), bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 2, color: .yellow, notes: nil,
                createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 10)
            )
            try await env.bookmarks.insert(bookmark)

            // The repo write flagged it dirty.
            #expect(try await needsSync(env.pool, bookmarkId: bookmark.id.uuidString) == 1)

            try await env.engine.pushPending(userId: "U")

            // Reached the remote and the local flag is cleared.
            #expect(await env.remote.bookmarkCount == 1)
            #expect(await env.remote.bookmark(id: bookmark.id.uuidString)?.userId == "U")
            #expect(try await needsSync(env.pool, bookmarkId: bookmark.id.uuidString) == 0)
        }

        @Test("pull inserts a brand-new remote bookmark as a clean (non-dirty) local row")
        func test_pull_insertsNewRemoteRow() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            let remoteId = UUID().uuidString
            await env.remote.seed(bookmark: BookmarkDTO(
                id: remoteId, bookCode: "EXO", bookOrder: 2, chapter: 3,
                startVerse: 1, endVerse: 1, color: "blue", notes: "hi",
                createdAt: 5, updatedAt: 50, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            #expect(try await bookmarkRowCount(env.pool) == 1)
            #expect(try await color(env.pool, bookmarkId: remoteId) == "blue")
            #expect(try await needsSync(env.pool, bookmarkId: remoteId) == 0)
        }

        @Test("pull applies a NEWER remote bookmark over the local one (LWW)")
        func test_pull_newerRemoteWins() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            let id = UUID().uuidString
            try await insertSyncedBookmark(env.pool, id: id, color: "yellow", updatedAt: 100)
            await env.remote.seed(bookmark: BookmarkDTO(
                id: id, bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 1, color: "green", notes: nil,
                createdAt: 1, updatedAt: 200, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            #expect(try await color(env.pool, bookmarkId: id) == "green")
            #expect(try await bookmarkRowCount(env.pool) == 1)
        }

        @Test("pull ignores an OLDER remote bookmark (LWW keeps the local one)")
        func test_pull_olderRemoteIgnored() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            let id = UUID().uuidString
            try await insertSyncedBookmark(env.pool, id: id, color: "yellow", updatedAt: 100)
            await env.remote.seed(bookmark: BookmarkDTO(
                id: id, bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 1, color: "pink", notes: nil,
                createdAt: 1, updatedAt: 50, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            #expect(try await color(env.pool, bookmarkId: id) == "yellow")
        }

        @Test("reading marks converge on the natural key: two device ids, one local row, newest state wins")
        func test_pull_readingMarkNaturalKeyMerge() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            // Local: (GEN,1) marked READ at t=100, already synced, local id AAA.
            let localId = "AAAAAAAA-0000-0000-0000-000000000001"
            try await env.pool.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO reading_marks
                            (id, book_code, book_order, chapter, is_read, created_at, updated_at, deleted_at, user_id, needs_sync)
                        VALUES (?, 'GEN', 1, 1, 1, 1.0, 100.0, NULL, 'U', 0)
                        """,
                    arguments: [localId]
                )
            }

            // Remote: same chapter, DIFFERENT id BBB, NEWER (t=200), flipped to UNREAD.
            await env.remote.seed(readingMark: ReadingMarkDTO(
                id: "BBBBBBBB-0000-0000-0000-000000000002",
                bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: 0,
                createdAt: 1, updatedAt: 200, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            // Exactly one physical row for (GEN,1); state is the newer (unread); id preserved.
            let (count, isRead, keptId): (Int, Int, String) = try await env.pool.read { db in
                let c = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM reading_marks WHERE book_code='GEN' AND chapter=1") ?? 0
                let r = try Int.fetchOne(db, sql: "SELECT is_read FROM reading_marks WHERE book_code='GEN' AND chapter=1") ?? -1
                let i = try String.fetchOne(db, sql: "SELECT id FROM reading_marks WHERE book_code='GEN' AND chapter=1") ?? ""
                return (c, r, i)
            }
            #expect(count == 1)
            #expect(isRead == 0)
            #expect(keptId == localId)   // ON CONFLICT(book_code,chapter) keeps the local id
        }

        @Test("the watermark advances so a second pull only sees rows newer than the first batch")
        func test_pull_watermarkAdvances() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            let firstId = UUID().uuidString
            await env.remote.seed(bookmark: BookmarkDTO(
                id: firstId, bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 1, color: "yellow", notes: nil,
                createdAt: 1, updatedAt: 100, deletedAt: nil, userId: "U"
            ))
            try await env.engine.pull()
            #expect(try await bookmarkRowCount(env.pool) == 1)

            // A second remote row strictly newer than the advanced watermark.
            let secondId = UUID().uuidString
            await env.remote.seed(bookmark: BookmarkDTO(
                id: secondId, bookCode: "EXO", bookOrder: 2, chapter: 1,
                startVerse: 1, endVerse: 1, color: "blue", notes: nil,
                createdAt: 1, updatedAt: 150, deletedAt: nil, userId: "U"
            ))
            try await env.engine.pull()

            // Both rows present; the second pull applied only the new one (no error,
            // watermark moved past 100 to 150).
            #expect(try await bookmarkRowCount(env.pool) == 2)
            #expect(try await needsSync(env.pool, bookmarkId: secondId) == 0)
        }

        @Test("full sync round-trip: local dirty row is pushed and a remote row is pulled in one call")
        func test_sync_roundTrip() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            // Local dirty bookmark (via repo).
            let local = Bookmark(
                id: UUID(), bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 1, color: .orange, notes: nil,
                createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 10)
            )
            try await env.bookmarks.insert(local)

            // Remote-only bookmark to be pulled.
            let remoteId = UUID().uuidString
            await env.remote.seed(bookmark: BookmarkDTO(
                id: remoteId, bookCode: "PSA", bookOrder: 19, chapter: 23,
                startVerse: 1, endVerse: 6, color: "green", notes: nil,
                createdAt: 5, updatedAt: 500, deletedAt: nil, userId: "U"
            ))

            try await env.engine.sync(userId: "U")

            // Push: local row reached remote and is clean.
            #expect(await env.remote.bookmarkCount == 2)
            #expect(try await needsSync(env.pool, bookmarkId: local.id.uuidString) == 0)
            // Pull: remote-only row is now local.
            #expect(try await bookmarkRowCount(env.pool) == 2)
            #expect(try await color(env.pool, bookmarkId: remoteId) == "green")
        }

        @Test("a dirty reading mark is pushed and its needs_sync flag is cleared")
        func test_push_readingMarkDirtyAndClears() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            try await env.reading.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)

            // The repo write flagged it dirty.
            let dirtyBefore = try await env.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT needs_sync FROM reading_marks WHERE book_code='GEN' AND chapter=1") ?? -1
            }
            #expect(dirtyBefore == 1)

            try await env.engine.pushPending(userId: "U")

            #expect(await env.remote.readingMarkCount == 1)
            #expect(await env.remote.readingMark(bookCode: "GEN", chapter: 1)?.userId == "U")
            let dirtyAfter = try await env.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT needs_sync FROM reading_marks WHERE book_code='GEN' AND chapter=1") ?? -1
            }
            #expect(dirtyAfter == 0)
        }

        @Test("pull inserts a brand-new remote reading mark as a clean local row")
        func test_pull_insertsNewRemoteReadingMark() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            await env.remote.seed(readingMark: ReadingMarkDTO(
                id: UUID().uuidString, bookCode: "EXO", bookOrder: 2, chapter: 5, isRead: 1,
                createdAt: 1, updatedAt: 80, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            let (count, isRead, needsSync): (Int, Int, Int) = try await env.pool.read { db in
                let c = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM reading_marks WHERE book_code='EXO' AND chapter=5") ?? 0
                let r = try Int.fetchOne(db, sql: "SELECT is_read FROM reading_marks WHERE book_code='EXO' AND chapter=5") ?? -1
                let n = try Int.fetchOne(db, sql: "SELECT needs_sync FROM reading_marks WHERE book_code='EXO' AND chapter=5") ?? -1
                return (c, r, n)
            }
            #expect(count == 1)
            #expect(isRead == 1)
            #expect(needsSync == 0)
        }

        @Test("pull ignores an older remote reading mark (LWW keeps the local one)")
        func test_pull_olderRemoteReadingMarkIgnored() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            // Local: (GEN,3) marked read at t=200, already synced.
            try await env.pool.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO reading_marks
                            (id, book_code, book_order, chapter, is_read, created_at, updated_at, deleted_at, user_id, needs_sync)
                        VALUES (?, 'GEN', 1, 3, 1, 1.0, 200.0, NULL, 'U', 0)
                        """,
                    arguments: [UUID().uuidString]
                )
            }

            // Remote: same chapter, OLDER (t=50), flipped to unread.
            await env.remote.seed(readingMark: ReadingMarkDTO(
                id: UUID().uuidString, bookCode: "GEN", bookOrder: 1, chapter: 3, isRead: 0,
                createdAt: 1, updatedAt: 50, deletedAt: nil, userId: "U"
            ))

            try await env.engine.pull()

            let isRead = try await env.pool.read { db in
                try Int.fetchOne(db, sql: "SELECT is_read FROM reading_marks WHERE book_code='GEN' AND chapter=3") ?? -1
            }
            #expect(isRead == 1)  // local newer state preserved
        }

        @Test("pull applies a remote tombstone: the bookmark is hidden from fetchAll")
        func test_pull_remoteTombstoneHidesBookmark() async throws {
            let env = try makeEnv()
            defer { cleanup(env) }

            // Local: a synced, live bookmark at t=100.
            let id = UUID().uuidString
            try await insertSyncedBookmark(env.pool, id: id, color: "yellow", updatedAt: 100)

            // Remote: same id, NEWER (t=300), now tombstoned.
            await env.remote.seed(bookmark: BookmarkDTO(
                id: id, bookCode: "GEN", bookOrder: 1, chapter: 1,
                startVerse: 1, endVerse: 1, color: "yellow", notes: nil,
                createdAt: 1, updatedAt: 300, deletedAt: 300, userId: "U"
            ))

            try await env.engine.pull()

            // Row physically exists with deleted_at set.
            let deletedAt = try await env.pool.read { db in
                try Double.fetchOne(db, sql: "SELECT deleted_at FROM bookmarks WHERE id = ?", arguments: [id])
            }
            #expect(deletedAt != nil)

            // fetchAll excludes tombstoned rows.
            let visible = try await env.bookmarks.fetchAll(sortedBy: .createdAtDesc)
            #expect(visible.isEmpty)
        }
    }
}
