//
//  BookmarkDTO.swift
//  HagaBible
//
//  Wire format for the Supabase `bookmarks` mirror table. Mirrors the local
//  GRDB columns 1:1 *except* `needs_sync`, which is a per-device concept and is
//  never sent to the server. Timestamps are epoch seconds (`Double`) to match the
//  local REAL columns exactly — no date/timezone parsing in the round-trip.
//
//  Security: `user_id` is included in the push payload, but the server RLS
//  policy (`WITH CHECK (user_id = auth.uid())`) ensures a client can never
//  write a row scoped to another user — any mismatch is rejected outright.
//

import Foundation

// `nonisolated`: a pure wire-format value built inside the `actor SyncEngine`'s
// nonisolated `.map` closures. Without this it inherits the target's default
// `@MainActor` isolation and its `init(record:userId:)` can't be called there.
nonisolated struct BookmarkDTO: Codable, Sendable, Equatable {
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
    let deletedAt: Double?
    /// Scoped to the signed-in user. On push the client stamps `auth.uid()`;
    /// the server RLS `WITH CHECK` rejects any value that doesn't match.
    let userId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case bookCode = "book_code"
        case bookOrder = "book_order"
        case chapter
        case startVerse = "start_verse"
        case endVerse = "end_verse"
        case color
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case userId = "user_id"
    }
}

extension BookmarkDTO {
    /// Build a push payload from a local row, stamping the signed-in user's id so
    /// the server row is scoped to the right account (the local row's `user_id` may
    /// still be NULL on the first sync after sign-in).
    // `nonisolated`: built inside `actor SyncEngine`'s nonisolated `.map` closures.
    // Members in an extension don't inherit the type's `nonisolated`, so annotate here.
    nonisolated init(record: BookmarkRecord, userId: String) {
        self.id = record.id
        self.bookCode = record.bookCode
        self.bookOrder = record.bookOrder
        self.chapter = record.chapter
        self.startVerse = record.startVerse
        self.endVerse = record.endVerse
        self.color = record.color
        self.notes = record.notes
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.deletedAt = record.deletedAt
        self.userId = userId
    }
}
