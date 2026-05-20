//
//  UserDataDatabaseServiceTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
import GRDB
@testable import HagaBible

@Suite("UserDataDatabaseService Tests")
struct UserDataDatabaseServiceTests {

    // MARK: - Helpers

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-userdata-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        // GRDB also creates -wal and -shm sidecar files
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    // MARK: - Tests

    @Test("init creates the SQLite file at the given path")
    func test_init_createsDatabase() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)

        #expect(service.dbPool != nil)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("v1 migration creates the bookmarks table")
    func test_migration_v1_createsBookmarksTable() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)
        let pool = try #require(service.dbPool)

        let tableExists = try pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'bookmarks'"
            ) ?? 0
        }

        #expect(tableExists == 1)
    }

    @Test("v1 migration creates both required indexes")
    func test_migration_v1_createsIndexes() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)
        let pool = try #require(service.dbPool)

        let indexNames = try pool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'bookmarks'"
            )
        }

        #expect(indexNames.contains("idx_bookmarks_book_chapter"))
        #expect(indexNames.contains("idx_bookmarks_created_at"))
    }

    @Test("v2 migration adds the sync columns deleted_at and user_id")
    func test_migration_v2_addsSyncColumns() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)
        let pool = try #require(service.dbPool)

        let columns = try pool.read { db -> [String] in
            try Row.fetchAll(db, sql: "PRAGMA table_info(bookmarks)").map { row in row["name"] }
        }

        #expect(columns.contains("deleted_at"))
        #expect(columns.contains("user_id"))
    }

    @Test("v2 migration adds the updated_at index")
    func test_migration_v2_addsUpdatedAtIndex() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)
        let pool = try #require(service.dbPool)

        let indexNames = try pool.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'bookmarks'"
            )
        }

        #expect(indexNames.contains("idx_bookmarks_updated_at"))
    }

    @Test("re-initialising at the same path preserves previously inserted rows")
    func test_repeated_init_preservesData() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        // First init: insert a raw row
        let id = UUID().uuidString
        do {
            let service = try UserDataDatabaseService(databaseFileURL: url)
            let pool = try #require(service.dbPool)
            try pool.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO bookmarks
                            (id, book_code, book_order, chapter, start_verse, end_verse,
                             color, notes, created_at, updated_at)
                        VALUES (?, 'GEN', 1, 1, 1, 1, 'yellow', NULL, 1.0, 1.0)
                    """,
                    arguments: [id]
                )
            }
            // Fully close the first connection (checkpoints the WAL into the main
            // database file) before re-opening. Otherwise two pools race for the
            // same file and the second init's migration surfaces "database is
            // locked" while reading the schema.
            try pool.close()
        }

        // Second init at the same path: row must still be there
        let service2 = try UserDataDatabaseService(databaseFileURL: url)
        let pool2 = try #require(service2.dbPool)

        let count = try pool2.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM bookmarks WHERE id = ?",
                arguments: [id]
            ) ?? 0
        }

        #expect(count == 1)
    }

    @Test("running the migrator twice on the same pool does not throw")
    func test_migration_idempotent() throws {
        let url = makeTempURL()
        defer { cleanup(url) }

        let service = try UserDataDatabaseService(databaseFileURL: url)
        let pool = try #require(service.dbPool)

        // Build a fresh migrator identical to the one in the service and run it again.
        // GRDB's DatabaseMigrator skips already-applied migrations — no error expected.
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_bookmarks") { db in
            try db.execute(sql: """
                CREATE TABLE bookmarks (
                    id TEXT PRIMARY KEY NOT NULL,
                    book_code TEXT NOT NULL,
                    book_order INTEGER NOT NULL,
                    chapter INTEGER NOT NULL,
                    start_verse INTEGER NOT NULL,
                    end_verse INTEGER NOT NULL,
                    color TEXT NOT NULL,
                    notes TEXT,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );
                CREATE INDEX idx_bookmarks_book_chapter ON bookmarks(book_order, chapter);
                CREATE INDEX idx_bookmarks_created_at ON bookmarks(created_at);
            """)
        }

        // Must not throw
        try migrator.migrate(pool)
    }
}
