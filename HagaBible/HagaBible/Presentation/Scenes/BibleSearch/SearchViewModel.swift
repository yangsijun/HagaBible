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
    private let searchHistoryRepository: SearchHistoryRepository
    
    var bibleReferenceText: String? = nil
    var bibleReferenceVerse: BibleVerse? = nil
    
    var searchResults: [BibleVerse] = []
    var groupedSearchResults: [BibleBook: [BibleVerse]] = [:]
//    var searchHistories: [SearchHistory] {
//        do {
//            print("fetch")
//            return try searchHistoryRepository.fetchSearchHistories()
//        } catch {
//            return []
//        }
//    }
    var searchHistories: [SearchHistory] = []
        
    init(
        appState: AppState,
        bibleRepository: BibleRepository,
        bibleReaderViewModel: BibleReaderViewModel,
        searchHistoryRepository: SearchHistoryRepository
    ) {
        self.appState = appState
        self.bibleRepository = bibleRepository
        self.bibleReaderViewModel = bibleReaderViewModel
        self.searchHistoryRepository = searchHistoryRepository
    }
    
    private func parseBibleReference(_ input: String) -> (book: String, chapter: Int?, verse: Int?) {
        let pattern = #"^(.+?)\s*(?:(\d+)(?:[:장]\s*(\d+)?[절]?)?)?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (input, nil, nil)
        }
        
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        if let match = regex.firstMatch(in: input, options: [], range: range) {
            let book = Range(match.range(at: 1), in: input).map { String(input[$0]) } ?? ""
            let chapter = Range(match.range(at: 2), in: input).flatMap { Int(input[$0]) }
            let verse = Range(match.range(at: 3), in: input).flatMap { Int(input[$0]) }
            return (book, chapter, verse)
        }
        
        return (input, nil, nil)
    }
    
    func findBibleReference(text: String) {
        guard !text.isEmpty else {
            bibleReferenceText = nil
            bibleReferenceVerse = nil
            return
        }
        guard let bibleVersion = appState.bibleReaderState.bibleVersion else {
            bibleReferenceText = nil
            bibleReferenceVerse = nil
            return
        }
        
        let (parsedBookName, parsedChapterNum, parsedVerseNum) = parseBibleReference(text)
        
        if let book = bibleReaderViewModel.bibleBookList.first(where: { $0.bookName.lowercased() == parsedBookName.lowercased() }) {
            let bookName = book.bookName
            let chapterNum = parsedChapterNum ?? 1
            let verseNum = parsedVerseNum ?? 1
            
            Task {
                bibleReferenceVerse = try await bibleRepository.fetchBibleVerse(versionCode: bibleVersion.versionCode, bookCode: book.bookCode, chapter: chapterNum, verse: verseNum)
                bibleReferenceText = "\(bookName) \(chapterNum):\(verseNum)"
            }
        } else {
            bibleReferenceVerse = nil
            return
        }
    }
    
    func search(text: String) {
        guard !text.isEmpty else {
            searchResults = []
            groupedSearchResults = [:]
            return
        }
        guard let bibleVersion = appState.bibleReaderState.bibleVersion else {
            searchResults = []
            groupedSearchResults = [:]
            return
        }
        
        Task {
            do {
                searchResults = try await bibleRepository.findByVerseTextContaining(versionCode: bibleVersion.versionCode, keyword: text)
                let bibleBookList = try await bibleRepository.fetchBibleBookList(versionCode: bibleVersion.versionCode)
                
                groupedSearchResults = Dictionary(grouping: searchResults) { verse in
                    bibleBookList.first(where: { $0.bookCode == verse.bookCode })!
                }
            } catch {
#if DEBUG
                print("Failed to search by text: \(error)")
#endif
                searchResults = []
                groupedSearchResults = [:]
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
        bibleReaderViewModel.applyBibleSelection(
            versionCode: verse.versionCode,
            bookCode: verse.bookCode,
            chapterNum: verse.chapter,
            verseNum: verse.verse
        )
        
        bibleReaderViewModel.navigatedVerseNum = verse.verse

        appState.selectedTab = .bibleReader        
        
        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
    }
    
    func addSearchHistory(from verse: BibleVerse) {
        do {
            try searchHistoryRepository.addSearchHistory(SearchHistory(verse: verse))
        } catch {
#if DEBUG
            print("Failed to add search history: \(error)")
#endif
        }
    }

    func loadSearchHistory() {
        do {
            print("fetch")
            searchHistories = try searchHistoryRepository.fetchSearchHistories()
        } catch {
#if DEBUG
            print("Failed to fetch search histories: \(error)")
#endif
        }
    }
    
    func deleteSearchHistory(_ searchHistory: SearchHistory) {
        do {
            try searchHistoryRepository.deleteSearchHistory(searchHistory)
        } catch {
#if DEBUG
            print("Failed to delete search history: \(error)")
#endif
        }
    }
    
    func clearSearchHistory() {
        do {
            try searchHistoryRepository.deleteAllSearchHistories()
        } catch {
#if DEBUG
            print("Failed to delete all search histories: \(error)")
#endif
        }
    }
}
