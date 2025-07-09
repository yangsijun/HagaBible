//
//  BibleReaderViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

import Observation

@Observable
@MainActor
class BibleReaderViewModel {
    var isLoading: Bool = false
    var isLoadingSuccess: Bool?
    
    var bibleRepository: BibleRepository
    
    var availableVersions: [BibleVersion] = []
    var version: BibleVersion?
    var bibleContent: BibleContent?
    
    var bookName: String? {
        book?.bookName
    }
    var books: [Book]? {
        bibleContent?.books
    }
    var bookNum: Int
    var book: Book? {
        bibleContent?.books[bookNum - 1]
    }
    
    var chapterNum: Int
    var chapter: Chapter? {
        book?.chapters[chapterNum - 1]
    }
    
    var verseNum: Int?
    var verses: [Verse]? {
        chapter?.verses
    }
    var navigatedVerseNum: Int?
    
    var fontConfiguration: FontConfiguration = FontConfiguration(
        type: .sans,
        style: .regular,
        size: 17
    )
    
    init(bibleRepository: BibleRepository, bookNum: Int = 1, chapterNum: Int = 1) {
        self.bibleRepository = bibleRepository
        self.bookNum = bookNum
        self.chapterNum = chapterNum
    }
    
    func fetchAvailableVersions() async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            availableVersions = try await bibleRepository.getAvailableVersions()
        } catch {
            print("Error fetching available versions: \(error)")
        }
    }
    
    func selectVersion(versionId: String) async {
        version = availableVersions.first(where: { $0.id == versionId })
        
        if let versionId = version?.id {
            await fetchBibleContent(versionId: versionId)
        }
    }
    
    func fetchBibleContent(versionId: String) async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            bibleContent = try await bibleRepository.getBibleContent(versionId: versionId)
            self.version = version
            if let books = bibleContent?.books, let bookCode = self.book?.book {
                if !books.contains(where: { $0.book == bookCode }) {
                    self.bookNum = 1
                    self.chapterNum = 1
                }
                if chapterNum > (book?.chapters.count ?? 0) {
                    chapterNum = books[bookNum - 1].chapters.count
                }
            }
            isLoadingSuccess = true
        } catch {
            print("Error fetching Bible content: \(error)")
        }
    }
    
    // TODO: Chapter가 끝나면 Book을 이동하도록 수정
    func getPrevChapter() {
        if chapterNum > 1 {
            chapterNum -= 1
        } else {
            if bookNum > 1 {
                bookNum -= 1
                chapterNum = book?.chapters.count ?? 0
            }
        }
    }
    
    func getNextChapter() {
        if chapterNum < (book?.chapters.count ?? 0) {
            chapterNum += 1
        } else {
            if bookNum < (bibleContent?.books.count ?? 0) {
                bookNum += 1
                chapterNum = 1
            }
        }
    }
    
    var bibleNavigationUpdateTrigger: Bool = false
}
