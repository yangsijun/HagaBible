//
//  OpenBibleReferenceIntent.swift
//  HagaBible
//
//  App Shortcut / Siri / Spotlight entry point for 주소검색 (address lookup) that
//  JUMPS into the reader. Resolves a free-text reference ("요한복음 3장 16절",
//  "John 3:16") to a canonical book/chapter/verse and drives the same reader
//  navigation the in-app search uses (`gotoVerse`): switch to the Bible tab and
//  scroll to the verse in the currently-loaded translation. Also used as the
//  "Open in Reader" action of `LookUpBibleVerseIntent`'s inline snippet.
//

import AppIntents

struct OpenBibleReferenceIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Bible Verse"
    static let description = IntentDescription("Open a specific Bible reference in the reader.")

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Bible Reference", requestValueDialog: "Which verse? (e.g. John 3:16)")
    var reference: String

    // Optional — defaults to the reader's current translation when left unset.
    @Parameter(title: "Translation")
    var version: BibleVersionEntity?

    init() {}

    init(reference: String, version: BibleVersionEntity? = nil) {
        self.reference = reference
        self.version = version
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DIContainer.registerDependenciesIfNeeded()
        let appState = DIContainer.shared.resolve(type: AppState.self)

        guard let resolved = BibleReferenceResolver.resolve(reference) else {
            // Book couldn't be resolved — fall back to the Search tab with the raw text,
            // so an ambiguous phrase still lands somewhere useful.
            appState.pendingSearchQuery = reference
            appState.selectedTab = .search
            return .result()
        }

        let reader = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
        // versionCode: the chosen translation, else nil to keep the reader's current one;
        // the canonical book code is shared across versions, so the reference resolves
        // everywhere. Awaited so the position is applied before the scroll trigger fires.
        await reader.applyBibleSelectionAsync(
            versionCode: version?.id,
            bookCode: resolved.bookCode,
            chapterNum: resolved.chapter,
            verseNum: resolved.verse
        )
        reader.navigatedVerseNum = resolved.verse
        appState.selectedTab = .bibleReader
        reader.bibleNavigationUpdateTrigger.toggle()
        return .result()
    }
}
