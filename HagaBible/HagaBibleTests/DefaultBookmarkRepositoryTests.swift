//
//  DefaultBookmarkRepositoryTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
import GRDB
@testable import HagaBible

// Tests are serialised because they share DIContainer.shared (singleton).
// Serialisation prevents cross-test DI state pollution.
@Suite("DefaultBookmarkRepository Tests", .serialized)
struct DefaultBookmarkRepositoryTests {

    // MARK: - Setup helpers

    /// Creates an isolated UserDataDatabaseService at a unique temp path,
    /// registers it in DIContainer, and returns both the service URL (for
    /// teardown) and a fresh DefaultBookmarkRepository.
    private func makeIsolatedRepo() throws -> (repo: DefaultBookmarkRepository, tempURL: URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-bookmarks-\(UUID().uuidString).sqlite")
        let service = try UserDataDatabaseService(databaseFileURL: url)
        DIContainer.shared.register(type: UserDataDatabaseService.self, component: service)
        return (DefaultBookmarkRepository(), url)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    /// Builds a minimal Bookmark entity with sensible defaults.
    private func makeBookmark(
        id: UUID = UUID(),
        bookCode: String = "GEN",
        bookOrder: Int = 1,
        chapter: Int = 1,
        startVerse: Int = 1,
        endVerse: Int = 1,
        color: BookmarkColor = .yellow,
        notes: String? = nil,
        createdAt: Date = Date()
    ) -> Bookmark {
        Bookmark(
            id: id,
            bookCode: bookCode,
            bookOrder: bookOrder,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
            color: color,
            notes: notes,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    // MARK: - Tests

    @Test("insert and fetchAll returns bookmarks newest-first when sorted by createdAtDesc")
    func test_insert_and_fetchAll_createdAtDesc() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let t1 = Date(timeIntervalSinceReferenceDate: 2_000_000)
        let t2 = Date(timeIntervalSinceReferenceDate: 3_000_000)

        let oldest = makeBookmark(bookCode: "GEN", chapter: 1, createdAt: t0)
        let middle = makeBookmark(bookCode: "GEN", chapter: 2, createdAt: t1)
        let newest = makeBookmark(bookCode: "GEN", chapter: 3, createdAt: t2)

        try await repo.insert(oldest)
        try await repo.insert(middle)
        try await repo.insert(newest)

        let results = try await repo.fetchAll(sortedBy: .createdAtDesc)

        #expect(results.count == 3)
        #expect(results[0].createdAt >= results[1].createdAt)
        #expect(results[1].createdAt >= results[2].createdAt)
        #expect(results[0].id == newest.id)
        #expect(results[2].id == oldest.id)
    }

    @Test("insert and fetchAll returns bookmarks in biblical order when sorted by biblicalOrder")
    func test_insert_and_fetchAll_biblicalOrder() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        // Insert out of order
        let rev = makeBookmark(bookCode: "REV", bookOrder: 66, chapter: 22, startVerse: 21)
        let gen = makeBookmark(bookCode: "GEN", bookOrder: 1,  chapter: 1,  startVerse: 1)
        let exo = makeBookmark(bookCode: "EXO", bookOrder: 2,  chapter: 3,  startVerse: 5)

        try await repo.insert(rev)
        try await repo.insert(gen)
        try await repo.insert(exo)

        let results = try await repo.fetchAll(sortedBy: .biblicalOrder)

        #expect(results.count == 3)
        #expect(results[0].bookOrder <= results[1].bookOrder)
        #expect(results[1].bookOrder <= results[2].bookOrder)
        #expect(results[0].id == gen.id)
        #expect(results[1].id == exo.id)
        #expect(results[2].id == rev.id)
    }

    @Test("fetchForChapter returns only bookmarks matching the given book order and chapter")
    func test_fetchForChapter_returnsOnlyMatching() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        // 2 bookmarks in GEN ch1, 1 in GEN ch2, 1 in EXO ch1
        let gen1a = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 1)
        let gen1b = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 5)
        let gen2  = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 2, startVerse: 1)
        let exo1  = makeBookmark(bookCode: "EXO", bookOrder: 2, chapter: 1, startVerse: 1)

        try await repo.insert(gen1a)
        try await repo.insert(gen1b)
        try await repo.insert(gen2)
        try await repo.insert(exo1)

        let results = try await repo.fetchForChapter(bookOrder: 1, chapter: 1)

        #expect(results.count == 2)
        let ids = results.map(\.id)
        #expect(ids.contains(gen1a.id))
        #expect(ids.contains(gen1b.id))
    }

    @Test("fetchFiltered by color returns only bookmarks with the matching color")
    func test_fetchFiltered_byColor() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let blue   = makeBookmark(bookCode: "GEN", chapter: 1, startVerse: 1, color: .blue)
        let yellow = makeBookmark(bookCode: "GEN", chapter: 1, startVerse: 2, color: .yellow)
        let green  = makeBookmark(bookCode: "GEN", chapter: 1, startVerse: 3, color: .green)

        try await repo.insert(blue)
        try await repo.insert(yellow)
        try await repo.insert(green)

        let results = try await repo.fetchFiltered(color: .blue, bookCode: nil, keyword: nil)

        #expect(results.count == 1)
        #expect(results[0].color == .blue)
        #expect(results[0].id == blue.id)
    }

    @Test("fetchFiltered by bookCode returns only bookmarks from that book")
    func test_fetchFiltered_byBookCode() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let gen = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1)
        let exo = makeBookmark(bookCode: "EXO", bookOrder: 2, chapter: 1)
        let lev = makeBookmark(bookCode: "LEV", bookOrder: 3, chapter: 1)

        try await repo.insert(gen)
        try await repo.insert(exo)
        try await repo.insert(lev)

        let results = try await repo.fetchFiltered(color: nil, bookCode: "GEN", keyword: nil)

        #expect(results.count == 1)
        #expect(results[0].bookCode == "GEN")
        #expect(results[0].id == gen.id)
    }

    @Test("fetchFiltered by keyword returns only bookmarks whose notes contain the keyword")
    func test_fetchFiltered_byKeyword() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let loveStory    = makeBookmark(bookCode: "GEN", chapter: 1, startVerse: 1, notes: "love story")
        let warChronicle = makeBookmark(bookCode: "GEN", chapter: 1, startVerse: 2, notes: "war chronicle")

        try await repo.insert(loveStory)
        try await repo.insert(warChronicle)

        let results = try await repo.fetchFiltered(color: nil, bookCode: nil, keyword: "love")

        #expect(results.count == 1)
        #expect(results[0].id == loveStory.id)
    }

    @Test("update persists changes to color and notes")
    func test_update_changesColorAndNotes() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let original = makeBookmark(color: .yellow, notes: "original note")
        try await repo.insert(original)

        let updated = Bookmark(
            id: original.id,
            bookCode: original.bookCode,
            bookOrder: original.bookOrder,
            chapter: original.chapter,
            startVerse: original.startVerse,
            endVerse: original.endVerse,
            color: .pink,
            notes: "updated note",
            createdAt: original.createdAt,
            updatedAt: Date()
        )
        try await repo.update(updated)

        let all = try await repo.fetchAll(sortedBy: .createdAtDesc)
        #expect(all.count == 1)
        #expect(all[0].color == .pink)
        #expect(all[0].notes == "updated note")
    }

    @Test("delete removes the bookmark so fetchAll returns empty")
    func test_delete_removesBookmark() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let bookmark = makeBookmark()
        try await repo.insert(bookmark)

        try await repo.delete(id: bookmark.id)

        let all = try await repo.fetchAll(sortedBy: .createdAtDesc)
        #expect(all.isEmpty)
    }

    @Test("delete is a soft delete: row remains as a tombstone but is excluded from every read path")
    func test_delete_isSoftDelete() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let bookmark = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1, notes: "to delete")
        try await repo.insert(bookmark)
        try await repo.delete(id: bookmark.id)

        // Excluded from all read paths
        #expect(try await repo.fetchAll(sortedBy: .createdAtDesc).isEmpty)
        #expect(try await repo.fetchForChapter(bookOrder: 1, chapter: 1).isEmpty)
        #expect(try await repo.fetchFiltered(color: nil, bookCode: "GEN", keyword: "to delete").isEmpty)

        // But the row physically remains with deleted_at populated (tombstone for sync)
        let pool = try #require(DIContainer.shared.resolve(type: UserDataDatabaseService.self).dbPool)
        let tombstoneCount = try await pool.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM bookmarks WHERE id = ? AND deleted_at IS NOT NULL",
                arguments: [bookmark.id.uuidString]
            ) ?? 0
        }
        #expect(tombstoneCount == 1)
    }

    @Test("two bookmarks with the same verse range but different colors are both stored")
    func test_duplicateRange_allowed() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let yellow = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1,
                                  startVerse: 1, endVerse: 3, color: .yellow)
        let blue   = makeBookmark(bookCode: "GEN", bookOrder: 1, chapter: 1,
                                  startVerse: 1, endVerse: 3, color: .blue)

        try await repo.insert(yellow)
        try await repo.insert(blue)

        let all = try await repo.fetchAll(sortedBy: .createdAtDesc)
        #expect(all.count == 2)
        let colors = Set(all.map(\.color))
        #expect(colors.contains(.yellow))
        #expect(colors.contains(.blue))
    }

    @Test("inserting a bookmark with a duplicate primary key throws an error")
    func test_insert_failure_throws() async throws {
        let (repo, url) = try makeIsolatedRepo()
        defer { cleanup(url) }

        let sharedID = UUID()
        let first  = makeBookmark(id: sharedID, bookCode: "GEN", chapter: 1)
        let second = makeBookmark(id: sharedID, bookCode: "GEN", chapter: 2)

        try await repo.insert(first)

        // The schema enforces PRIMARY KEY uniqueness on `id`.
        // The second insert with the same UUID must throw.
        var didThrow = false
        do {
            try await repo.insert(second)
        } catch {
            didThrow = true
        }

        #expect(didThrow, "Expected insert of duplicate primary key to throw, but it did not")
    }
}
