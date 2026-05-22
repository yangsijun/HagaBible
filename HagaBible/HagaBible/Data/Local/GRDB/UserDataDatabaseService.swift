//
//  UserDataDatabaseService.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation
import GRDB
import OSLog

final class UserDataDatabaseService {
    private(set) var dbPool: DatabasePool?

    convenience init() throws {
        let appSupportURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("UserData.sqlite")
        try self.init(databaseFileURL: appSupportURL)
    }

    /// Designated initializer — accepts an explicit file URL so tests can use a
    /// temp path instead of the real Application Support directory.
    init(databaseFileURL dbUrl: URL) throws {
        let fileManager = FileManager.default

        // Create parent directory if needed
        let supportDir = dbUrl.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: supportDir.path) {
            try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }

        Logger.database.debug("UserData DB path: \(dbUrl.path, privacy: .public)")

        do {
            let pool = try DatabasePool(path: dbUrl.path)
            self.dbPool = pool
            try migrator.migrate(pool)
            Logger.database.info("UserData migration completed successfully")
        } catch {
            Logger.database.error("UserData database initialisation error: \(error.localizedDescription)")
            throw error
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

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

        // Sync-readiness: tombstone for delete propagation, user_id for per-user
        // scoping (nullable until auth lands), and an updated_at index for delta sync.
        migrator.registerMigration("v2_add_bookmark_sync_columns") { db in
            try db.execute(sql: """
                ALTER TABLE bookmarks ADD COLUMN deleted_at REAL;
                ALTER TABLE bookmarks ADD COLUMN user_id TEXT;
                CREATE INDEX idx_bookmarks_updated_at ON bookmarks(updated_at);
            """)
        }

        // Reading checklist (성경읽기표): one row per (book_code, chapter). New table,
        // so the sync columns (deleted_at, user_id) are included from the start —
        // same sync contract as bookmarks. The identity is `book_code` (version- and
        // platform-independent), matching the bookmarks table which also carries both
        // book_code and book_order; book_order is denormalized for biblical-order
        // sorting. updated_at index for delta sync.
        migrator.registerMigration("v3_create_reading_marks") { db in
            try db.execute(sql: """
                CREATE TABLE reading_marks (
                    id TEXT PRIMARY KEY NOT NULL,
                    book_code TEXT NOT NULL,
                    book_order INTEGER NOT NULL,
                    chapter INTEGER NOT NULL,
                    is_read INTEGER NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    deleted_at REAL,
                    user_id TEXT
                );
                CREATE UNIQUE INDEX idx_reading_marks_book_chapter ON reading_marks(book_code, chapter);
                CREATE INDEX idx_reading_marks_updated_at ON reading_marks(updated_at);
            """)
        }

        return migrator
    }
}
