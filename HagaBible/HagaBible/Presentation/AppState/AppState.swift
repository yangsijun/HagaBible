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
    var bibleReaderState = BibleReaderState()
}

struct BibleReaderState {
    var bibleVersion: BibleVersion?
    var bibleBook: BibleBook?
    var bibleChapter: BibleChapter?
    var bibleVerse: BibleVerse?
}
