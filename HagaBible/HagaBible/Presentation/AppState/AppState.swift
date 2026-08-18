//
//  AppState.swift
//  HagaBible
//
//  Created by 양시준 on 10/4/25.
//

import Foundation
import OSLog

@Observable
@MainActor
class AppState {
    var selectedTab: TabIdentifier = .bibleReader

    /// Which Library segment to show. Shared so the reader's toolbar can route to
    /// a specific section (Bookmarks or 성경읽기표) when it switches to the tab.
    var librarySection: LibrarySection = .bookmarks

    /// Book order (1–66) the 성경읽기표 should scroll to when the Library tab opens,
    /// set by the reader's "Reading Checklist" toolbar action; cleared once consumed.
    var pendingReadingScrollBookOrder: Int?

    /// Search text an external entry point (App Shortcut / Siri / Spotlight) wants the
    /// Search tab to run. Set by `SearchBibleTextIntent`; `RootView` copies it into the
    /// `.searchable` field (which fires the existing search pipeline) and clears it.
    /// Consume-once, mirroring `pendingReadingScrollBookOrder`.
    var pendingSearchQuery: String?

    /// Request that the Search tab's search field take focus (raise the keyboard, ready
    /// to type). Set by `OpenBibleSearchIntent` (the Control Center control) so a tap opens
    /// the app straight into an active search field. `RootView` drives the `.searchable`
    /// `isPresented` binding from it and clears it. Consume-once.
    var pendingSearchFocus: Bool = false

    /// 초기 다운로드 완료 후 BibleReaderView 리로드 트리거
    var initialDownloadCompleted: Bool = false

    /// Whether the per-verse bookmark indicator is shown in the reader. Single,
    /// observable source of truth so a toggle (e.g. from the bookmarks sheet)
    /// reflects immediately everywhere; persisted via BookmarkPreferences.
    var bookmarkIndicatorEnabled: Bool = BookmarkPreferences.isIndicatorEnabled {
        didSet { BookmarkPreferences.isIndicatorEnabled = bookmarkIndicatorEnabled }
    }

    /// Experimental ("Labs") feature toggles — opt-in, default off, persisted via
    /// `ExperimentalFeaturePreferences`. Observable so flipping one immediately
    /// shows/hides the dependent UI: the reader's "Listen" action + the TTS mini
    /// player (TTS), and the Recordings tab (recording).
    var isTTSEnabled: Bool = ExperimentalFeaturePreferences.isTTSEnabled {
        didSet { ExperimentalFeaturePreferences.isTTSEnabled = isTTSEnabled }
    }
    var isRecordingEnabled: Bool = ExperimentalFeaturePreferences.isRecordingEnabled {
        didSet { ExperimentalFeaturePreferences.isRecordingEnabled = isRecordingEnabled }
    }

    /// Screen-wake settings for the reader, persisted via `ScreenDisplayPreferences`.
    /// `keepScreenOn` (default true) keeps the display awake; when on,
    /// `screenDimAfterSeconds` (default 0 = never) dims the brightness after that
    /// many seconds of inactivity. Observable so changes apply live in the reader.
    var keepScreenOn: Bool = ScreenDisplayPreferences.keepScreenOn {
        didSet { ScreenDisplayPreferences.keepScreenOn = keepScreenOn }
    }
    var screenDimAfterSeconds: Int = ScreenDisplayPreferences.dimAfterSeconds {
        didSet { ScreenDisplayPreferences.dimAfterSeconds = screenDimAfterSeconds }
    }

    /// Alarm-style list of Bible-reading reminders, persisted via
    /// `ReadingReminderPreferences`. Observable so the list UI reflects changes live; the
    /// schedule is reconciled through `NotificationService` whenever the list changes
    /// (see `ReadingReminderView`) and on launch (`RootView`).
    var readingReminders: [ReadingReminder] = ReadingReminderPreferences.reminders {
        didSet { ReadingReminderPreferences.reminders = readingReminders }
    }

    /// Live, in-memory reader position (full entities), consumed across the app. NOT the
    /// persistence format — see `saveBibleReaderState()`.
    var bibleReaderState = BibleReaderState() {
        didSet {
            saveBibleReaderState()
        }
    }

    /// The reader's last position restored from disk as plain identifiers. The reader resolves
    /// these into full entities on launch (`BibleReaderViewModel.init`). Persisting primitives
    /// rather than the full Codable entities is deliberate: adding a field to `BibleVersion`/
    /// `BibleBook`/… used to invalidate the whole saved blob (synthesized `Codable` throws on a
    /// missing key), silently resetting the reader to WEBBE Genesis 1 after every schema-changing
    /// update. Primitives can't be invalidated that way. `nil` when nothing is saved yet.
    private(set) var restoredReaderPosition: PersistedReaderPosition?

    private let bibleReaderStateKey = "bibleReaderState"

    init() {
        loadBibleReaderState()
    }

    private func saveBibleReaderState() {
        let position = PersistedReaderPosition(
            versionCode: bibleReaderState.bibleVersion?.versionCode,
            bookCode: bibleReaderState.bibleBook?.bookCode,
            chapter: bibleReaderState.bibleChapter?.chapter,
            verse: bibleReaderState.bibleVerse?.verse
        )
        // Never let a transient loading state clobber the durable position. While entities
        // resolve one by one (and in headless App Intent launches, where the reader UI never
        // loads, they resolve to nil and STAY nil), this didSet fires with partial/empty
        // state; writing that to disk is how the reader kept resetting to WEBBE Genesis 1.
        // Persist only once the position is meaningful. `verse` may be nil (it falls back to
        // 1 on restore), so it doesn't gate the write.
        guard position.versionCode != nil, position.bookCode != nil, position.chapter != nil else { return }
        persist(position)
    }

    private func persist(_ position: PersistedReaderPosition) {
        do {
            let data = try JSONEncoder().encode(position)
            UserDefaults.standard.set(data, forKey: bibleReaderStateKey)
        } catch {
            Logger.app.error("Failed to persist reader position: \(error.localizedDescription)")
        }
    }

    private func loadBibleReaderState() {
        guard let savedData = UserDefaults.standard.data(forKey: bibleReaderStateKey) else { return }

        // Order matters. The legacy full-entity format and the new primitive format have DISJOINT
        // top-level keys ("bibleVersion"… vs "versionCode"…), so each decodes as the other with
        // every field nil — a false success. So try the legacy shape first and only accept it when
        // it actually carries a position; a new-format blob yields all-nil entities here and is
        // skipped. Older builds stored the full Codable entities, which is the fragility we're
        // migrating away from — salvage the identifiers and rewrite in the durable format.
        if let legacy = try? JSONDecoder().decode(BibleReaderState.self, from: savedData),
           legacy.bibleVersion != nil || legacy.bibleBook != nil
            || legacy.bibleChapter != nil || legacy.bibleVerse != nil {
            let salvaged = PersistedReaderPosition(
                versionCode: legacy.bibleVersion?.versionCode,
                bookCode: legacy.bibleBook?.bookCode,
                chapter: legacy.bibleChapter?.chapter,
                verse: legacy.bibleVerse?.verse
            )
            restoredReaderPosition = salvaged
            persist(salvaged)
            return
        }

        // The durable primitive format (all fields optional, so this only throws on genuinely
        // corrupt data).
        do {
            restoredReaderPosition = try JSONDecoder().decode(PersistedReaderPosition.self, from: savedData)
        } catch {
            // Unreadable blob (e.g. a legacy entity whose schema changed so the full decode above
            // threw). Start from the default position for this launch; the reader re-persists in
            // the new format on first use.
            Logger.app.error("Reader position blob unreadable; resetting to default position: \(error.localizedDescription)")
            restoredReaderPosition = nil
        }
    }
}

struct BibleReaderState: Codable, Equatable {
    var bibleVersion: BibleVersion?
    var bibleBook: BibleBook?
    var bibleChapter: BibleChapter?
    var bibleVerse: BibleVerse?
}

/// Durable, schema-stable persistence shape for the reader's last position: plain identifiers
/// only, resolved back into full entities on launch. See `AppState.restoredReaderPosition`.
struct PersistedReaderPosition: Codable, Equatable {
    var versionCode: String?
    var bookCode: String?
    var chapter: Int?
    var verse: Int?
}
