//
//  AppState.swift
//  HagaBible
//
//  Created by 양시준 on 10/4/25.
//

import Foundation

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

    var bibleReaderState = BibleReaderState() {
        didSet {
            saveBibleReaderState()
        }
    }
    
    private let bibleReaderStateKey = "bibleReaderState"
    
    init() {
        loadBibleReaderState()
    }
    
    private func saveBibleReaderState() {
        if let encodedData = try? JSONEncoder().encode(bibleReaderState) {
            UserDefaults.standard.set(encodedData, forKey: bibleReaderStateKey)
        }
    }

    private func loadBibleReaderState() {
        if let savedData = UserDefaults.standard.data(forKey: bibleReaderStateKey),
           let decodedState = try? JSONDecoder().decode(BibleReaderState.self, from: savedData) {
            self.bibleReaderState = decodedState
        }
    }
}

struct BibleReaderState: Codable, Equatable {
    var bibleVersion: BibleVersion?
    var bibleBook: BibleBook?
    var bibleChapter: BibleChapter?
    var bibleVerse: BibleVerse?
}
