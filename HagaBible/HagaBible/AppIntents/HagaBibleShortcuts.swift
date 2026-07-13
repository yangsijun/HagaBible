//
//  HagaBibleShortcuts.swift
//  HagaBible
//
//  Declares the app's App Shortcuts. Declaring them here makes each intent available
//  automatically in the Shortcuts app, in Siri (via the phrases), and in Spotlight
//  search results — no per-surface wiring required. Phrases must embed
//  `\(.applicationName)`; localized (Korean) phrasings live in the App Shortcuts
//  string catalog and are harvested like the rest of the app's UI strings.
//

import AppIntents

struct HagaBibleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchBibleTextIntent(),
            phrases: [
                "Search the Bible in \(.applicationName)",
                "Search \(.applicationName)",
                "\(.applicationName)에서 성경 검색"
            ],
            shortTitle: "Search the Bible",
            systemImageName: "magnifyingglass"
        )

        // Free-text `String` parameters can't be embedded in App Shortcut phrases (only
        // AppEntity/AppEnum can). Siri prompts for the reference via `requestValueDialog`
        // when one of these phrases is spoken.
        AppShortcut(
            intent: LookUpBibleVerseIntent(),
            phrases: [
                "Look up a verse in \(.applicationName)",
                "Look up a Bible verse with \(.applicationName)"
            ],
            shortTitle: "Look Up a Verse",
            systemImageName: "text.book.closed"
        )

        AppShortcut(
            intent: OpenBibleReferenceIntent(),
            phrases: [
                "Open a Bible verse in \(.applicationName)",
                "Open a verse in \(.applicationName)"
            ],
            shortTitle: "Open a Verse",
            systemImageName: "book"
        )
    }
}
