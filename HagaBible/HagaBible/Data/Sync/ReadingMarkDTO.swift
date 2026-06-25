//
//  ReadingMarkDTO.swift
//  HagaBible
//
//  Wire format for the Supabase `reading_marks` mirror table. Identity on the
//  server is the natural key (user_id, book_code, chapter) — `id` may differ
//  between devices that marked the same chapter offline, so it is carried but is
//  not the conflict key. Timestamps are epoch seconds to match local REAL columns.
//
//  Security: `user_id` is included in the push payload, but the server RLS
//  policy (`WITH CHECK (user_id = auth.uid())`) ensures a client can never
//  write a row scoped to another user — any mismatch is rejected outright.
//

import Foundation

struct ReadingMarkDTO: Codable, Sendable, Equatable {
    let id: String
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let isRead: Int
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    /// Scoped to the signed-in user. On push the client stamps `auth.uid()`;
    /// the server RLS `WITH CHECK` rejects any value that doesn't match.
    let userId: String?

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
    }
}

extension ReadingMarkDTO {
    /// Build a push payload from a local row, stamping the signed-in user's id.
    init(record: ReadingMarkRecord, userId: String) {
        self.id = record.id
        self.bookCode = record.bookCode
        self.bookOrder = record.bookOrder
        self.chapter = record.chapter
        self.isRead = record.isRead
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.deletedAt = record.deletedAt
        self.userId = userId
    }
}
