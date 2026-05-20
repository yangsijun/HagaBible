//
//  BookmarkRecord.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import GRDB

struct BookmarkRecord: Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "bookmarks"

    let id: String
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let startVerse: Int
    let endVerse: Int
    let color: String
    let notes: String?
    let createdAt: Double
    let updatedAt: Double
    // Sync-only fields — not surfaced on the domain `Bookmark`.
    let deletedAt: Double?
    let userId: String?

    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case bookCode = "book_code"
        case bookOrder = "book_order"
        case chapter = "chapter"
        case startVerse = "start_verse"
        case endVerse = "end_verse"
        case color = "color"
        case notes = "notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case userId = "user_id"
    }
}
