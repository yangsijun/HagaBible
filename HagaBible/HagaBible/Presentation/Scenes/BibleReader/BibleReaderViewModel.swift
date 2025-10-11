//
//  BibleReaderViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

import Observation
import Foundation

@Observable
@MainActor
class BibleReaderViewModel {
    private let appState: AppState
    
    var isLoading: Bool = false
    var isLoadingSuccess: Bool?
    
    var bibleRepository: BibleRepository
    
    var bibleVersion: BibleVersion? {
        get {
            appState.bibleReaderState.bibleVersion
        }
        set {
            appState.bibleReaderState.bibleVersion = newValue
        }
    }
    var bibleBook: BibleBook? {
        get {
            appState.bibleReaderState.bibleBook
        }
        set {
            appState.bibleReaderState.bibleBook = newValue
        }
    }
    var bibleChapter: BibleChapter? {
        get {
            appState.bibleReaderState.bibleChapter
        }
        set {
            appState.bibleReaderState.bibleChapter = newValue
        }
    }
    var bibleVerse: BibleVerse? {
        get {
            appState.bibleReaderState.bibleVerse
        }
        set {
            appState.bibleReaderState.bibleVerse = newValue
        }
    }
    
    var availableVersions: [BibleVersion] = []
    var bibleBookList: [BibleBook] = []
    var bibleChapterList: [BibleChapter] = []
    var bibleVerseList: [BibleVerse] = []
    
    var versionCode: String {
        didSet {
            Task {
                await fetchBibleVersion()
            }
        }
    }
    var bookCode: String {
        didSet {
            Task {
                await fetchBibleBook()
            }
        }
    }
    var chapterNum: Int {
        didSet {
            Task {
                await fetchBibleChapter()
            }
        }
    }
    var verseNum: Int {
        didSet {
            fetchBibleVerse()
        }
    }
    
    var navigatedVerseNum: Int?
    
    init(appState: AppState, bibleRepository: BibleRepository) {
        self.appState = appState
        
        self.bibleRepository = bibleRepository
        
        self.versionCode = appState.bibleReaderState.bibleVersion?.versionCode ?? "WEBBE"
        self.bookCode = appState.bibleReaderState.bibleBook?.bookCode ?? "GEN"
        self.chapterNum = appState.bibleReaderState.bibleChapter?.chapter ?? 1
        self.verseNum = appState.bibleReaderState.bibleVerse?.verse ?? 1
    }
    
    func fetchAvailableVersions() async {
            do {
                availableVersions = try await bibleRepository.fetchBibleVersionList()
            } catch {
#if DEBUG
                print("Error fetching available versions: \(error)")
#endif
            }
    }
    
    func fetchBibleVersion() async {
        bibleVersion = availableVersions.first { $0.versionCode == versionCode }
        if let versionCode = bibleVersion?.versionCode {
            await fetchBibleBookList(versionCode: versionCode)
        }
    }
    
    func fetchBibleBookList(versionCode: String) async {
            do {
                bibleBookList = try await bibleRepository.fetchBibleBookList(versionCode: versionCode)
            } catch {
#if DEBUG
                print("Error fetching books: \(error)")
#endif
            }
    }
    
    func fetchBibleBook() async {
        bibleBook = bibleBookList.first { $0.bookCode == bookCode }
        if let bookCode = bibleBook?.bookCode {
            await fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
        }
    }
    
    func fetchBibleChapterList(versionCode: String, bookCode: String) async {
            do {
                bibleChapterList = try await bibleRepository.fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
            } catch {
#if DEBUG
                print("Error fetching chapters: \(error)")
#endif
            }
    }
    
    func fetchBibleChapter() async {
        bibleChapter = bibleChapterList.first { $0.chapter == chapterNum }
        if let chapterNum = bibleChapter?.chapter {
            await fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapterNum: chapterNum)
        }
    }
    
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapterNum: Int) async {
            do {
                bibleVerseList = try await bibleRepository.fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapter: chapterNum)
            } catch {
#if DEBUG
                print("Error fetching verses: \(error)")
#endif
            }
    }
    
    func fetchBibleVerse() {
        bibleVerse = bibleVerseList.first(where: { $0.verse == verseNum })
    }
    
    func goToPreviousChapter() {
        if chapterNum > 1 {
            self.chapterNum = chapterNum - 1
            self.verseNum = 1
            return
        }
        if let index = bibleBookList.firstIndex(of: bibleBookList.first(where: { $0.bookCode == bookCode })!) {
            if index == 0 { return }
            self.bookCode = bibleBookList[index - 1].bookCode
            self.chapterNum = bibleBookList[index - 1].totalChapters
            self.verseNum = 1
        }
    }
    
    func goToNextChapter() {
        if chapterNum < bibleChapterList.last!.chapter {
            self.chapterNum = chapterNum + 1
            Task {
                await fetchBibleChapter()
                self.verseNum = 1
            }
            return
        }
        if let index = bibleBookList.firstIndex(of: bibleBookList.first(where: { $0.bookCode == bookCode })!) {
            if index == bibleBookList.count - 1 { return }
            self.bookCode = bibleBookList[index + 1].bookCode
            self.chapterNum = 1
            self.verseNum = 1
        }
    }
    
    func getBibleBookListByVersion(of version: BibleVersion) async -> [BibleBook] {
        do {
            let bookList: [BibleBook] = try await bibleRepository.fetchBibleBookList(versionCode: version.versionCode)
            return bookList
        } catch {
#if DEBUG
            print("Error fetching book list: \(error)")
#endif
            return []
        }
    }
    
    func getBibleChapterListByBook(of book: BibleBook) async -> [BibleChapter] {
        do {
            let chapterList: [BibleChapter] = try await bibleRepository.fetchBibleChapterList(versionCode: book.versionCode, bookCode: book.bookCode)
            return chapterList
        } catch {
#if DEBUG
            print("Error fetching chapter list: \(error)")
#endif
            return []
        }
    }
    
    func getBibleVerseListByChapter(of chapter: BibleChapter) async -> [BibleVerse] {
        do {
            let verseList: [BibleVerse] = try await bibleRepository.fetchBibleVerseList(versionCode: chapter.versionCode, bookCode: chapter.bookCode, chapter: chapter.chapter)
            return verseList
        } catch {
#if DEBUG
            print("Error fetching verse list: \(error)")
#endif
            return []
        }
    }
    
    var bibleNavigationUpdateTrigger: Bool = false
}
