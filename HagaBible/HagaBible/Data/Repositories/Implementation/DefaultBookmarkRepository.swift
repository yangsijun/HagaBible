//
//  DefaultBookmarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation
import GRDB
import OSLog

final class DefaultBookmarkRepository: BookmarkRepository {

    // MARK: - Insert

    func insert(_ bookmark: Bookmark) async throws {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return
        }
        do {
            let record = toRecord(bookmark)
            try await pool.write { db in
                try record.insert(db)
            }
            Logger.repository.debug("Bookmark inserted: \(bookmark.id.uuidString)")
        } catch {
            Logger.repository.error("Bookmark write failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Update

    func update(_ bookmark: Bookmark) async throws {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return
        }
        do {
            let record = toRecord(bookmark)
            try await pool.write { db in
                try record.update(db)
            }
            Logger.repository.debug("Bookmark updated: \(bookmark.id.uuidString)")
        } catch {
            Logger.repository.error("Bookmark write failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return
        }
        do {
            // Soft delete: keep the row as a tombstone so the deletion can be
            // propagated during sync. `updated_at` is bumped so delta sync picks it up.
            let now = Date().timeIntervalSince1970
            try await pool.write { db in
                try db.execute(
                    sql: "UPDATE bookmarks SET deleted_at = ?, updated_at = ?, needs_sync = 1 WHERE id = ?",
                    arguments: [now, now, id.uuidString]
                )
            }
            Logger.repository.debug("Bookmark soft-deleted: \(id.uuidString)")
        } catch {
            Logger.repository.error("Bookmark write failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch All

    func fetchAll(sortedBy sortOrder: BookmarkSortOrder) async throws -> [Bookmark] {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return []
        }
        let orderClause: String
        switch sortOrder {
        case .createdAtDesc:
            orderClause = "ORDER BY created_at DESC"
        case .biblicalOrder:
            orderClause = "ORDER BY book_order ASC, chapter ASC, start_verse ASC"
        }
        let sql = "SELECT * FROM bookmarks WHERE deleted_at IS NULL \(orderClause)"
        return try await pool.read { db in
            let records = try BookmarkRecord.fetchAll(db, sql: sql, arguments: [])
            return records.map { self.toEntity($0) }
        }
    }

    // MARK: - Fetch For Chapter

    func fetchForChapter(bookOrder: Int, chapter: Int) async throws -> [Bookmark] {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return []
        }
        let sql = "SELECT * FROM bookmarks WHERE book_order = ? AND chapter = ? AND deleted_at IS NULL"
        return try await pool.read { db in
            let records = try BookmarkRecord.fetchAll(db, sql: sql, arguments: [bookOrder, chapter])
            return records.map { self.toEntity($0) }
        }
    }

    // MARK: - Fetch Filtered

    func fetchFiltered(color: BookmarkColor?, bookCode: String?, keyword: String?) async throws -> [Bookmark] {
        guard let pool = DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool else {
            return []
        }

        var conditions: [String] = ["deleted_at IS NULL"]
        var arguments: [DatabaseValueConvertible] = []

        if let color = color {
            conditions.append("color = ?")
            arguments.append(color.rawValue)
        }
        if let bookCode = bookCode {
            conditions.append("book_code = ?")
            arguments.append(bookCode)
        }
        if let keyword = keyword, !keyword.isEmpty {
            conditions.append("notes LIKE '%' || ? || '%'")
            arguments.append(keyword)
        }

        let whereClause = "WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT * FROM bookmarks \(whereClause) ORDER BY created_at DESC"
        let stmtArgs = StatementArguments(arguments) ?? StatementArguments()

        return try await pool.read { db in
            let records = try BookmarkRecord.fetchAll(db, sql: sql, arguments: stmtArgs)
            return records.map { self.toEntity($0) }
        }
    }

    // MARK: - Mapping Helpers

    nonisolated private func toRecord(_ bookmark: Bookmark) -> BookmarkRecord {
        BookmarkRecord(
            id: bookmark.id.uuidString,
            bookCode: bookmark.bookCode,
            bookOrder: bookmark.bookOrder,
            chapter: bookmark.chapter,
            startVerse: bookmark.startVerse,
            endVerse: bookmark.endVerse,
            color: bookmark.color.rawValue,
            notes: bookmark.notes,
            createdAt: bookmark.createdAt.timeIntervalSince1970,
            updatedAt: bookmark.updatedAt.timeIntervalSince1970,
            // Domain `Bookmark` carries neither field; writes from the domain are
            // always "live" and unscoped. A server-assigned user_id is only set by
            // the (future) sync layer, which must not round-trip through `toRecord`.
            deletedAt: nil,
            userId: nil,
            // Every domain write is a local change that must be pushed.
            needsSync: 1
        )
    }

    nonisolated private func toEntity(_ record: BookmarkRecord) -> Bookmark {
        Bookmark(
            id: UUID(uuidString: record.id) ?? UUID(),
            bookCode: record.bookCode,
            bookOrder: record.bookOrder,
            chapter: record.chapter,
            startVerse: record.startVerse,
            endVerse: record.endVerse,
            color: BookmarkColor(rawValue: record.color) ?? .yellow,
            notes: record.notes,
            createdAt: Date(timeIntervalSince1970: record.createdAt),
            updatedAt: Date(timeIntervalSince1970: record.updatedAt)
        )
    }
}
