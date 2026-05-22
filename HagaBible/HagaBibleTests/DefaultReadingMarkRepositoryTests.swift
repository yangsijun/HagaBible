//
//  DefaultReadingMarkRepositoryTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
import GRDB
@testable import HagaBible

/// Serialized umbrella for every suite that registers a shared
/// UserDataDatabaseService into DIContainer.shared. The container is a
/// process-wide singleton, so these suites must not run in parallel — otherwise
/// they race the registration (crash) and clobber each other's database.
@Suite(.serialized)
struct UserDataSuites {}

extension UserDataSuites {
    @Suite("DefaultReadingMarkRepository Tests", .serialized)
    struct DefaultReadingMarkRepositoryTests {

    // MARK: - Setup helpers

    private func makeIsolatedRepo() throws -> (repo: DefaultReadingMarkRepository, tempURL: URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-readingmarks-\(UUID().uuidString).sqlite")
        let service = try UserDataDatabaseService(databaseFileURL: url)
        DIContainer.shared.register(type: UserDataDatabaseService.self, component: service)
        return (DefaultReadingMarkRepository(), url)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    /// Read chapter numbers (sorted) for a book — replaces the dropped
    /// `fetchReadChapters` convenience by filtering `fetchAll`.
    private func readChapters(_ repo: DefaultReadingMarkRepository, bookCode: String) async throws -> [Int] {
        try await repo.fetchAll()
            .filter { $0.bookCode == bookCode && $0.isRead }
            .map(\.chapter)
            .sorted()
    }

    private func pool() throws -> DatabasePool {
        try #require(DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool)
    }

    // MARK: - Tests

    @Test("setRead inserts a new mark and fetchAll returns it")
    func test_setRead_insertsNewMark() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 3, isRead: true)

        #expect(try await readChapters(repo, bookCode: "GEN") == [1, 3])
    }

    @Test("setRead is an upsert: toggling the same chapter keeps a single row")
    func test_setRead_isUpsert() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)  // again

        let rowCount = try await pool().read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM reading_marks WHERE book_code = 'GEN' AND chapter = 1"
            ) ?? 0
        }
        #expect(rowCount == 1)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1])
    }

    @Test("setRead false unmarks a previously read chapter")
    func test_setRead_unmark() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1])

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: false)
        #expect(try await readChapters(repo, bookCode: "GEN").isEmpty)
    }

    @Test("fetchAll is scoped per book and returned in biblical order")
    func test_fetchAll_scopedAndOrdered() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "EXO", bookOrder: 2, chapter: 1, isRead: true)
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 3, isRead: true)
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)

        let all = try await repo.fetchAll()
        #expect(all.count == 3)
        #expect(all[0].bookCode == "GEN" && all[0].chapter == 1)
        #expect(all[1].bookCode == "GEN" && all[1].chapter == 3)
        #expect(all[2].bookCode == "EXO" && all[2].chapter == 1)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1, 3])
        #expect(try await readChapters(repo, bookCode: "EXO") == [1])
    }

    @Test("an unread mark persists as a row but is excluded from the read set")
    func test_unreadMark_persistsButExcludedFromReadSet() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: false)

        #expect(try await readChapters(repo, bookCode: "GEN").isEmpty)

        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].isRead == false)
    }

    @Test("batch setRead writes/clears every chapter in one call")
    func test_setRead_batch() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapters: [1, 2, 3, 4, 5], isRead: true)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1, 2, 3, 4, 5])

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapters: [2, 3], isRead: false)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1, 4, 5])
    }

    @Test("setRead resurrects a tombstoned row instead of violating the UNIQUE index")
    func test_setRead_resurrectsTombstone() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        // Simulate a sync-written tombstone for (GEN, 1).
        try await pool().write { db in
            try db.execute(
                sql: """
                    INSERT INTO reading_marks
                        (id, book_code, book_order, chapter, is_read, created_at, updated_at, deleted_at, user_id)
                    VALUES (?, 'GEN', 1, 1, 1, 1.0, 1.0, 2.0, NULL)
                    """,
                arguments: [UUID().uuidString]
            )
        }
        // Tombstoned: excluded from live reads.
        #expect(try await readChapters(repo, bookCode: "GEN").isEmpty)

        // Re-marking must not throw (no INSERT/UNIQUE collision) and must resurrect.
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)

        #expect(try await readChapters(repo, bookCode: "GEN") == [1])

        // Still a single physical row (resurrected, not duplicated), now live.
        let physicalCount = try await pool().read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM reading_marks WHERE book_code = 'GEN' AND chapter = 1") ?? 0
        }
        #expect(physicalCount == 1)
    }

    @Test("setRead to an unchanged value does not bump updated_at")
    func test_setRead_noOpDoesNotBumpUpdatedAt() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        let before = try await pool().read { db in
            try Double.fetchOne(db, sql: "SELECT updated_at FROM reading_marks WHERE book_code = 'GEN' AND chapter = 1")
        }

        try await Task.sleep(for: .milliseconds(20))
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)  // same value

        let after = try await pool().read { db in
            try Double.fetchOne(db, sql: "SELECT updated_at FROM reading_marks WHERE book_code = 'GEN' AND chapter = 1")
        }
        #expect(before == after)
    }

    @Test("resetAll marks every chapter unread, keeps rows, and allows re-marking")
    func test_resetAll_clearsReadStateButKeepsRows() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        try await repo.setRead(bookCode: "EXO", bookOrder: 2, chapter: 5, isRead: true)

        try await repo.resetAll()

        #expect(try await readChapters(repo, bookCode: "GEN").isEmpty)
        #expect(try await readChapters(repo, bookCode: "EXO").isEmpty)

        // Rows are kept (not deleted), just flipped to unread.
        let all = try await repo.fetchAll()
        #expect(all.count == 2)
        #expect(all.allSatisfy { $0.isRead == false })

        // Re-marking a previously-reset chapter reuses its row (no UNIQUE
        // index violation on (book_code, chapter)).
        try await repo.setRead(bookCode: "GEN", bookOrder: 1, chapter: 1, isRead: true)
        #expect(try await readChapters(repo, bookCode: "GEN") == [1])
        #expect(try await repo.fetchAll().count == 2)
    }
    }
}
