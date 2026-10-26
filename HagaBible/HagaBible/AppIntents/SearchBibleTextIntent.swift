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
        // The chosen translation rides along with the query: the active window's `RootView`
        // switches its own reader to it before running the search (which uses the reader's
        // version). Set before the query, whose change triggers the handling.
        appState.pendingSearchVersionCode = version?.id
        appState.pendingSearchQuery = query
        return .result()
    }
}
