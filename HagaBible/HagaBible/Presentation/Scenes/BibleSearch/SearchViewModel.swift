//
//  SearchViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 10/6/25.
//

import Observation
import Foundation

@Observable
@MainActor
class SearchViewModel {
    private let appState: AppState
    private let bibleRepository: BibleRepository
    
    init(appState: AppState, bibleRepository: BibleRepository) {
        self.appState = appState
        self.bibleRepository = bibleRepository
    }
    
    func search(text: String) -> [BibleVerse] {
        if text.isEmpty {
            return []
        }
        
        var searchResults: [BibleVerse] = []
        
        if let bibleVersion = appState.bibleReaderState.bibleVersion {
            do {
                searchResults = try bibleRepository.findByVerseTextContaining(versionCode: bibleVersion.versionCode, keyword: text)
            } catch {
                print("Failed to search by text: \(error)")
                searchResults = []
            }
        }
        return searchResults
    }
    
    func getBibleReferenceString(verse: BibleVerse) -> String {
        do {
            let bookName = try bibleRepository.fetchBibleBookList(versionCode: verse.versionCode).first(where: { $0.bookCode == verse.bookCode })!.bookName
            return "\(bookName) \(verse.chapter):\(verse.verse)"
        } catch {
            return ""
        }
    }
}
