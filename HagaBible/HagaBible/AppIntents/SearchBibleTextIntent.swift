//
//  SearchBibleTextIntent.swift
//  HagaBible
//
//  App Shortcut / Siri / Spotlight entry point for 본문검색 (full-text search).
//  Opens the app to the Search tab with the query pre-filled, which fires the app's
//  existing search pipeline. Full-text search returns many verses, so — unlike the
//  address lookup — there is no inline result; the intent just routes into the app.
//

import AppIntents

struct SearchBibleTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Search the Bible"
    static let description = IntentDescription("Search Bible verses for a word or phrase.")

    // The intent manipulates app UI, so it must open and run in the app.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Search Text", requestValueDialog: "What would you like to search for?")
    var query: String

    // Optional — defaults to the reader's current translation when left unset.
    @Parameter(title: "Translation")
    var version: BibleVersionEntity?

    init() {}

    init(query: String, version: BibleVersionEntity? = nil) {
        self.query = query
        self.version = version
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DIContainer.registerDependenciesIfNeeded()
        let appState = DIContainer.shared.resolve(type: AppState.self)
        if let version {
            // Switch the app to the chosen translation *before* handing off the query, so
            // the search (which runs against the reader's current version) uses it. Awaited
            // so `bibleReaderState.bibleVersion` is updated before `RootView` runs the search.
            let reader = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
            await reader.applyBibleSelectionAsync(versionCode: version.id)
        }
        appState.pendingSearchQuery = query
        appState.selectedTab = .search
        return .result()
    }
}
