//
//  ReadingMarkRecord.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import GRDB

// `nonisolated`: pure data record used from GRDB's background database queue;
// see BookmarkRecord for the rationale. Kept symmetric so its PersistableRecord
// conformance stays usable off the main actor.
nonisolated struct ReadingMarkRecord: Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "reading_marks"

    let id: String              // UUID as TEXT
    let bookCode: String        // version-independent identity; the (book_code, chapter) sync key
    let bookOrder: Int
    let chapter: Int
    let isRead: Int             // 0 or 1
    let createdAt: Double       // UNIX timestamp (REAL)
    let updatedAt: Double
    // Sync-only fields — not surfaced on the domain `ReadingMark`.
    let deletedAt: Double?      // Soft-delete tombstone (unused by the UI; kept for sync contract)
    let userId: String?         // Per-user scoping (nullable until auth)
    let needsSync: Int          // Local-only dirty flag (1 = pending push). Never sent to Supabase.

    private enum CodingKeys: String, CodingKey {
        case id
        case bookCode = "book_code"
        case bookOrder = "book_order"
        case chapter
        case isRead = "is_read"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case userId = "user_id"
        case needsSync = "needs_sync"
    }
}
