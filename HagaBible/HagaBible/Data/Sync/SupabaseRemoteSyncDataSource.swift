//
//  SupabaseRemoteSyncDataSource.swift
//  HagaBible
//
//  PostgREST implementation of `RemoteSyncDataSource`. Push is an upsert whose
//  conflict target differs per table (bookmarks on `id`; reading marks on the
//  natural key user_id,book_code,chapter — matching the server UNIQUE). Pull is
//  a delta query (`updated_at > since`, ascending) including tombstones so
//  deletions propagate. `user_id` is omitted from the push payload (see the DTO
//  encoders): the server stamps `auth.uid()` via column DEFAULT + RLS, so a
//  client can never write rows scoped to another account.
//

import Foundation
import Supabase

final class SupabaseRemoteSyncDataSource: RemoteSyncDataSource {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Push

    func pushBookmarks(_ rows: [BookmarkDTO]) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from("bookmarks")
            .upsert(rows, onConflict: "id")
            .execute()
    }

    func pushReadingMarks(_ rows: [ReadingMarkDTO]) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from("reading_marks")
            .upsert(rows, onConflict: "user_id,book_code,chapter")
            .execute()
    }

    // MARK: - Pull

    func pullBookmarks(since: Double) async throws -> [BookmarkDTO] {
        try await client
            .from("bookmarks")
            .select()
            .gt("updated_at", value: since)
            .order("updated_at", ascending: true)
            .execute()
            .value
    }

    func pullReadingMarks(since: Double) async throws -> [ReadingMarkDTO] {
        try await client
            .from("reading_marks")
            .select()
            .gt("updated_at", value: since)
            .order("updated_at", ascending: true)
            .execute()
            .value
    }
}
