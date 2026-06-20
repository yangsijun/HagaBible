//
//  SearchViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 10/6/25.
//

import Foundation
import Observation
import OSLog

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
    var searchHistories: [SearchHistory] = []

    /// Downloaded versions, used to offer "open this verse in another translation"
    /// from a search result's context menu.
    var availableVersions: [BibleVersion] = []
        
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

        let parsed = BibleReferenceParser.parse(text)

        Task {
            var book: BibleBook? = bibleReaderViewModel.bibleBookList.first(where: { $0.bookName.lowercased() == parsed.book.lowercased() })

            // Resolve cross-language names/abbreviations (e.g. "Gen" while a Korean
            // version is loaded, or "창" while an English version is loaded) via the
            // version-independent canonical book code.
            if book == nil, let bookCode = BibleBookReference.bookCode(for: parsed.book) {
                book = bibleReaderViewModel.bibleBookList.first(where: { $0.bookCode == bookCode })
            }

            // Fallback: version-specific abbreviation table in the database.
            if book == nil {
                if let bookCode = try? await bibleRepository.findBookCodeByAbbreviation(versionCode: bibleVersion.versionCode, abbreviation: parsed.book) {
                    book = bibleReaderViewModel.bibleBookList.first(where: { $0.bookCode == bookCode })
                }
            }

            // Last resort: loose partial/substring match (e.g. "창세" → 창세기,
            // "genes" → Genesis), resolved to the best single canonical book.
            if book == nil, let bookCode = BibleBookReference.looseBookCodes(for: parsed.book).first {
                book = bibleReaderViewModel.bibleBookList.first(where: { $0.bookCode == bookCode })
            }

            guard let book = book else {
                bibleReferenceVerse = nil
                bibleReferenceText = nil
                return
            }

            let bookName = book.bookName
            let chapterNum = parsed.chapter ?? 1
            let verseNum = parsed.verse ?? 1

            bibleReferenceVerse = try await bibleRepository.fetchBibleVerse(versionCode: bibleVersion.versionCode, bookCode: book.bookCode, chapter: chapterNum, verse: verseNum)
            bibleReferenceText = "\(bookName) \(chapterNum):\(verseNum)"
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
                Logger.search.error("Failed to search by text: \(error.localizedDescription)")
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
    
    /// Returns the downloaded versions other than the verse's own, for offering
    /// the same passage in another version. (`availableVersions` is already
    /// filtered to downloaded versions.)
    func otherVersions(for verse: BibleVerse) -> [BibleVersion] {
        availableVersions.filter { $0.versionCode != verse.versionCode }
    }

    func loadAvailableVersions() {
        Task {
            do {
                availableVersions = try await bibleRepository.fetchBibleVersionList().filter { $0.isDownloaded }
            } catch {
                Logger.search.error("Failed to load available versions: \(error.localizedDescription)")
            }
        }
    }

    /// Opens the verse in the reader. Pass `versionCode` to open the same
    /// book/chapter/verse in a different translation than the verse came from.
    func gotoVerse(verse: BibleVerse, versionCode: String? = nil) {
        bibleReaderViewModel.applyBibleSelection(
            versionCode: versionCode ?? verse.versionCode,
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
            Logger.search.error("Failed to add search history: \(error.localizedDescription)")
        }
    }

    func loadSearchHistory() {
        do {
            searchHistories = try searchHistoryRepository.fetchSearchHistories()
        } catch {
            Logger.search.error("Failed to fetch search histories: \(error.localizedDescription)")
        }
    }
    
    func deleteSearchHistory(_ searchHistory: SearchHistory) {
        do {
            try searchHistoryRepository.deleteSearchHistory(searchHistory)
        } catch {
            Logger.search.error("Failed to delete search history: \(error.localizedDescription)")
        }
    }

    func clearSearchHistory() {
        do {
            try searchHistoryRepository.deleteAllSearchHistories()
        } catch {
            Logger.search.error("Failed to delete all search histories: \(error.localizedDescription)")
        }
    }
}
