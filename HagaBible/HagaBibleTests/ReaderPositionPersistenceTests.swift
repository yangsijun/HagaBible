//
//  ReaderPositionPersistenceTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
@testable import HagaBible

/// Regression coverage for the "reader resets to WEBBE Genesis 1 after an app update" bug.
///
/// Root cause: the reader's last position was persisted as the full `BibleReaderState`
/// (which embeds `BibleVersion`/`BibleBook`/…). `BibleVersion` gained non-optional fields
/// over time (`isDownloaded`, `versionShortName`); Swift's synthesized `Codable` throws
/// `.keyNotFound` decoding an older blob that lacks them, so the whole saved position was
/// discarded and the reader fell back to its defaults. The fix persists plain identifiers
/// (`PersistedReaderPosition`) instead, which no field addition can invalidate.
@Suite("Reader position persistence")
struct ReaderPositionPersistenceTests {

    @Test("PersistedReaderPosition round-trips through JSON")
    func test_roundTrips() throws {
        let position = PersistedReaderPosition(versionCode: "GAE", bookCode: "JHN", chapter: 3, verse: 16)
        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(PersistedReaderPosition.self, from: data)
        #expect(decoded == position)
    }

    /// The whole point of the fix: adding fields elsewhere must never invalidate a saved
    /// position. A payload with only a subset of keys (an "older" shape) still decodes,
    /// with the absent identifiers becoming `nil` rather than throwing.
    @Test("Missing and unknown keys decode without throwing")
    func test_tolerantDecoding() throws {
        let json = Data(#"{ "versionCode": "WEBBE", "chapter": 5, "futureField": "ignored" }"#.utf8)
        let decoded = try JSONDecoder().decode(PersistedReaderPosition.self, from: json)
        #expect(decoded.versionCode == "WEBBE")
        #expect(decoded.chapter == 5)
        #expect(decoded.bookCode == nil)
        #expect(decoded.verse == nil)
    }

    /// Documents the original fragility: a `BibleVersion` blob written before the schema grew
    /// no longer decodes, which is exactly what used to nuke the persisted `BibleReaderState`.
    @Test("Legacy BibleVersion JSON missing new fields fails synthesized decode")
    func test_legacyBibleVersionDecodeFails() {
        let legacyVersionJSON = Data(#"{ "versionCode": "WEBBE", "versionName": "World English Bible", "language": "English" }"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(BibleVersion.self, from: legacyVersionJSON)
        }
    }

    /// …but the identifier we actually need for restore (`versionCode`) survives regardless,
    /// because the durable format stores only primitives.
    @Test("The same position survives as primitives when the entity blob would not")
    func test_primitivesSurviveSchemaChange() throws {
        let json = Data(#"{ "versionCode": "WEBBE", "bookCode": "GEN", "chapter": 1, "verse": 1 }"#.utf8)
        let decoded = try JSONDecoder().decode(PersistedReaderPosition.self, from: json)
        #expect(decoded.versionCode == "WEBBE")
        #expect(decoded.bookCode == "GEN")
        #expect(decoded.chapter == 1)
        #expect(decoded.verse == 1)
    }
}

/// `AppState.loadBibleReaderState` restore/migration behaviour. These exercise the real
/// UserDefaults-backed load path, so each test brackets the shared key it touches.
@MainActor
@Suite("AppState reader-position restore")
struct AppStateReaderPositionRestoreTests {

    private static let key = "bibleReaderState"

    /// Runs `body` with the persistence key set to `data`, restoring whatever was there before.
    private func withPersistedBlob(_ data: Data?, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.data(forKey: Self.key)
        defer {
            if let previous { defaults.set(previous, forKey: Self.key) }
            else { defaults.removeObject(forKey: Self.key) }
        }
        if let data { defaults.set(data, forKey: Self.key) } else { defaults.removeObject(forKey: Self.key) }
        body()
    }

    @Test("New primitive blob restores the exact position")
    func test_restoresPrimitiveFormat() throws {
        let saved = try JSONEncoder().encode(
            PersistedReaderPosition(versionCode: "NIV", bookCode: "JHN", chapter: 3, verse: 16)
        )
        withPersistedBlob(saved) {
            let restored = AppState().restoredReaderPosition
            #expect(restored?.versionCode == "NIV")
            #expect(restored?.bookCode == "JHN")
            #expect(restored?.chapter == 3)
            #expect(restored?.verse == 16)
        }
    }

    /// The regression that motivated the fix: a blob written by an older build in the full-entity
    /// format must be migrated (identifiers salvaged), NOT silently dropped to the default. The
    /// two formats share no top-level keys, so the load must not mistake this for an empty
    /// primitive blob.
    @Test("Legacy full-entity blob is migrated, not reset to default")
    func test_migratesLegacyEntityBlob() throws {
        let legacy = BibleReaderState(
            bibleVersion: BibleVersion(versionCode: "GAE", versionName: "개역개정", versionShortName: "개역개정", language: "Korean", isDownloaded: true),
            bibleBook: BibleBook(bookCode: "PSA", bookName: "시편", bookOrder: 19, totalChapters: 150, versionCode: "GAE"),
            bibleChapter: BibleChapter(bookCode: "PSA", bookOrder: 19, chapter: 23, totalVerses: 6, versionCode: "GAE"),
            bibleVerse: BibleVerse(bookCode: "PSA", bookName: "시편", bookOrder: 19, chapter: 23, verse: 1, verseText: nil, versionCode: "GAE")
        )
        let saved = try JSONEncoder().encode(legacy)
        withPersistedBlob(saved) {
            let restored = AppState().restoredReaderPosition
            #expect(restored?.versionCode == "GAE")
            #expect(restored?.bookCode == "PSA")
            #expect(restored?.chapter == 23)
            #expect(restored?.verse == 1)
        }
    }

    @Test("No saved blob leaves the restored position nil")
    func test_noBlobIsNil() {
        withPersistedBlob(nil) {
            #expect(AppState().restoredReaderPosition == nil)
        }
    }

    // MARK: - Transient-state clobber protection

    /// Regression: headless App Intent launches (Siri/Spotlight/Control Center) build the DI
    /// graph, whose eager `BibleReaderViewModel.init` runs the fetch chain against an empty
    /// `availableVersions` — every entity resolves to nil and `bibleReaderState`'s didSet
    /// fires with an empty state. That write used to overwrite the saved position on disk,
    /// resetting the reader to WEBBE Genesis 1 on the next real launch.
    @Test("An all-nil reader state never overwrites the saved position")
    func test_emptyStateDoesNotClobberSavedPosition() throws {
        let saved = try JSONEncoder().encode(
            PersistedReaderPosition(versionCode: "GAE", bookCode: "PSA", chapter: 23, verse: 1)
        )
        withPersistedBlob(saved) {
            let appState = AppState()
            appState.bibleReaderState = BibleReaderState()

            let blob = UserDefaults.standard.data(forKey: Self.key)
            let onDisk = blob.flatMap { try? JSONDecoder().decode(PersistedReaderPosition.self, from: $0) }
            #expect(onDisk?.versionCode == "GAE")
            #expect(onDisk?.bookCode == "PSA")
            #expect(onDisk?.chapter == 23)
            #expect(onDisk?.verse == 1)
        }
    }

    /// While entities resolve one by one on launch, the state passes through partial shapes
    /// (version set, book/chapter still nil). Those must not touch the disk either.
    @Test("A partially resolved reader state does not overwrite the saved position")
    func test_partialStateDoesNotClobberSavedPosition() throws {
        let saved = try JSONEncoder().encode(
            PersistedReaderPosition(versionCode: "GAE", bookCode: "PSA", chapter: 23, verse: 1)
        )
        withPersistedBlob(saved) {
            let appState = AppState()
            appState.bibleReaderState = BibleReaderState(
                bibleVersion: BibleVersion(versionCode: "NIV", versionName: "NIV", versionShortName: "NIV", language: "English", isDownloaded: true)
            )

            let blob = UserDefaults.standard.data(forKey: Self.key)
            let onDisk = blob.flatMap { try? JSONDecoder().decode(PersistedReaderPosition.self, from: $0) }
            #expect(onDisk?.versionCode == "GAE")
            #expect(onDisk?.bookCode == "PSA")
            #expect(onDisk?.chapter == 23)
        }
    }

    /// The happy path still persists: once version/book/chapter are all resolved the
    /// position is written (verse may be nil — restore falls back to verse 1).
    @Test("A resolved reader state persists the new position")
    func test_resolvedStatePersists() throws {
        let saved = try JSONEncoder().encode(
            PersistedReaderPosition(versionCode: "GAE", bookCode: "PSA", chapter: 23, verse: 1)
        )
        withPersistedBlob(saved) {
            let appState = AppState()
            appState.bibleReaderState = BibleReaderState(
                bibleVersion: BibleVersion(versionCode: "NIV", versionName: "NIV", versionShortName: "NIV", language: "English", isDownloaded: true),
                bibleBook: BibleBook(bookCode: "JHN", bookName: "John", bookOrder: 43, totalChapters: 21, versionCode: "NIV"),
                bibleChapter: BibleChapter(bookCode: "JHN", bookOrder: 43, chapter: 3, totalVerses: 36, versionCode: "NIV"),
                bibleVerse: BibleVerse(bookCode: "JHN", bookName: "John", bookOrder: 43, chapter: 3, verse: 16, verseText: nil, versionCode: "NIV")
            )

            let blob = UserDefaults.standard.data(forKey: Self.key)
            let onDisk = blob.flatMap { try? JSONDecoder().decode(PersistedReaderPosition.self, from: $0) }
            #expect(onDisk?.versionCode == "NIV")
            #expect(onDisk?.bookCode == "JHN")
            #expect(onDisk?.chapter == 3)
            #expect(onDisk?.verse == 16)
        }
    }
}
