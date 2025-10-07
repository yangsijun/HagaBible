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
    private let bibleReaderViewModel: BibleReaderViewModel
    
    init(appState: AppState, bibleRepository: BibleRepository, bibleReaderViewModel: BibleReaderViewModel) {
        self.appState = appState
        self.bibleRepository = bibleRepository
        self.bibleReaderViewModel = bibleReaderViewModel
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
    
    func gotoVerse(verse: BibleVerse) {
        bibleReaderViewModel.bookCode = verse.bookCode
        bibleReaderViewModel.chapterNum = verse.chapter
        bibleReaderViewModel.navigatedVerseNum = verse.verse
        
        appState.selectedTab = .bibleReader
    }
}
