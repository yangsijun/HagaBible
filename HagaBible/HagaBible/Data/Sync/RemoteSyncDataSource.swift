//
//  RemoteSyncDataSource.swift
//  HagaBible
//
//  Network abstraction for the sync layer. The concrete implementation
//  (`SupabaseRemoteSyncDataSource`) talks to Supabase PostgREST; tests inject an
//  in-memory double. Keeping this a protocol is what makes `SyncEngine` unit-
//  testable with no network.
//

import Foundation

protocol RemoteSyncDataSource: Sendable {
    /// Upsert local changes. Bookmarks conflict on `id`; reading marks conflict on
    /// the natural key (user_id, book_code, chapter).
    func pushBookmarks(_ rows: [BookmarkDTO]) async throws
    func pushReadingMarks(_ rows: [ReadingMarkDTO]) async throws

    /// Fetch every row for the signed-in user whose `updated_at` is strictly
    /// greater than `since` (the delta watermark). Includes tombstones
    /// (`deleted_at != nil`) so deletions propagate.
    func pullBookmarks(since: Double) async throws -> [BookmarkDTO]
    func pullReadingMarks(since: Double) async throws -> [ReadingMarkDTO]
}
