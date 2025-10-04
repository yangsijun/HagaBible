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
        didSet(oldValue) {
            if oldValue != bibleReaderState {
                saveState()
            }
        }
    }
    
    private let userDefaultsKey = "appState"
    
    init() {
        loadState()
    }
    
    private func saveState() {
        if let encodedData = try? JSONEncoder().encode(bibleReaderState) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
            print("AppState가 저장되었습니다.")
        }
    }

    private func loadState() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedState = try? JSONDecoder().decode(BibleReaderState.self, from: savedData) {
            self.bibleReaderState = decodedState
            print("AppState를 불러왔습니다.")
        }
    }
}

struct BibleReaderState: Codable, Equatable {
    var bibleVersion: BibleVersion?
    var bibleBook: BibleBook?
    var bibleChapter: BibleChapter?
    var bibleVerse: BibleVerse?
}
