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
    var searchResults: [BibleVerse] = []
    
    init(appState: AppState, bibleRepository: BibleRepository, bibleReaderViewModel: BibleReaderViewModel) {
        self.appState = appState
        self.bibleRepository = bibleRepository
        self.bibleReaderViewModel = bibleReaderViewModel
    }
    
    func search(text: String) {
        guard !text.isEmpty else {
            searchResults = []
            return
        }
        guard let bibleVersion = appState.bibleReaderState.bibleVersion else {
            searchResults = []
            return
        }
        
        Task {
            do {
                searchResults = try await bibleRepository.findByVerseTextContaining(versionCode: bibleVersion.versionCode, keyword: text)
            } catch {
#if DEBUG
                print("Failed to search by text: \(error)")
#endif
                searchResults = []
            }
        }
    }
    
    func getBibleReferenceString(verse: BibleVerse) async -> String {
        do {
            let bookName = try await bibleRepository.fetchBibleBookList(versionCode: verse.versionCode).first(where: { $0.bookCode == verse.bookCode })!.bookName
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
