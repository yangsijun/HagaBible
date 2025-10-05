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
