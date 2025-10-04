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
            fetchBibleVersion()
        }
    }
    var bookCode: String {
        didSet {
            fetchBibleBook()
        }
    }
    var chapterNum: Int {
        didSet {
            fetchBibleChapter()
        }
    }
    var verseNum: Int {
        didSet {
            fetchBibleVerse()
        }
    }
    
    var navigatedVerseNum: Int?
    
    init(appState: AppState, bibleRepository: BibleRepository, versionCode: String = "WEBBE", bookCode: String = "GEN", chapter: Int = 1, verse: Int = 1) {
        self.appState = appState
        
        self.bibleRepository = bibleRepository
        
        self.versionCode = versionCode
        self.bookCode = bookCode
        self.chapterNum = chapter
        self.verseNum = verse
        
        fetchAvailableVersions()
        fetchBibleVersion()
        fetchBibleBook()
        fetchBibleChapter()
        fetchBibleVerse()
    }
    
    func fetchAvailableVersions() {
        do {
            availableVersions = try bibleRepository.fetchBibleVersionList()
        } catch {
            #if DEBUG
            print("Error fetching available versions: \(error)")
            #endif
        }
    }
    
    func fetchBibleVersion() {
        bibleVersion = availableVersions.first { $0.versionCode == versionCode }
        if let versionCode = bibleVersion?.versionCode {
            fetchBibleBookList(versionCode: versionCode)
        }
    }
    
    func fetchBibleBookList(versionCode: String)  {
        do {
            bibleBookList = try bibleRepository.fetchBibleBookList(versionCode: versionCode)
        } catch {
            #if DEBUG
            print("Error fetching books: \(error)")
            #endif
        }
    }
    
    func fetchBibleBook() {
        bibleBook = bibleBookList.first { $0.bookCode == bookCode }
        if let bookCode = bibleBook?.bookCode {
            fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
        }
    }
    
    func fetchBibleChapterList(versionCode: String, bookCode: String) {
        do {
            bibleChapterList = try bibleRepository.fetchBibleChapterList(versionCode: versionCode, bookCode: bookCode)
        } catch {
            #if DEBUG
            print("Error fetching chapters: \(error)")
            #endif
        }
    }
    
    func fetchBibleChapter() {
        bibleChapter = bibleChapterList.first { $0.chapter == chapterNum }
        if let chapterNum = bibleChapter?.chapter {
            fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapterNum: chapterNum)
        }
    }
    
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapterNum: Int) {
        do {
            bibleVerseList = try bibleRepository.fetchBibleVerseList(versionCode: versionCode, bookCode: bookCode, chapter: chapterNum)
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
            return
        }
        if let index = bibleBookList.firstIndex(of: bibleBookList.first(where: { $0.bookCode == bookCode })!) {
            if index == 0 { return }
            self.bookCode = bibleBookList[index - 1].bookCode
            self.chapterNum = bibleBookList[index - 1].totalChapters
            return
        }
    }
    
    func goToNextChapter() {
        if chapterNum < bibleChapterList.last!.chapter {
            self.chapterNum = chapterNum + 1
            fetchBibleChapter()
            return
        }
        if let index = bibleBookList.firstIndex(of: bibleBookList.first(where: { $0.bookCode == bookCode })!) {
            if index == bibleBookList.count - 1 { return }
            self.bookCode = bibleBookList[index + 1].bookCode
            self.chapterNum = 1
        }
    }
    
    func getBibleBookListByVersion(of version: BibleVersion) -> [BibleBook] {
        do {
            let bookList: [BibleBook] = try bibleRepository.fetchBibleBookList(versionCode: version.versionCode)
            return bookList
        } catch {
            #if DEBUG
            print("Error fetching book list: \(error)")
            #endif
            return []
        }
    }
    
    func getBibleChapterListByBook(of book: BibleBook) -> [BibleChapter] {
        do {
            let chapterList: [BibleChapter] = try bibleRepository.fetchBibleChapterList(versionCode: book.versionCode, bookCode: book.bookCode)
            return chapterList
        } catch {
            #if DEBUG
            print("Error fetching chapter list: \(error)")
            #endif
            return []
        }
    }
    
    func getBibleVerseListByChapter(of chapter: BibleChapter) -> [BibleVerse] {
        do {
            let verseList: [BibleVerse] = try bibleRepository.fetchBibleVerseList(versionCode: chapter.versionCode, bookCode: chapter.bookCode, chapter: chapter.chapter)
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
