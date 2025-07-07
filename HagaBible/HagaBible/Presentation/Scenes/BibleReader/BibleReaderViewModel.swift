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
    var bookNum: Int
    var book: Book? {
        bibleContent?.books[bookNum - 1]
    }
    
    var chapterNum: Int
    var chapter: Chapter? {
        book?.chapters[chapterNum - 1]
    }
    
    var verses: [Verse]? {
        chapter?.verses
    }
    
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
    
    func selectVersion(versionId: String) {
        version = availableVersions.first(where: { $0.id == versionId })
    }
    
    func fetchBibleContent(versionId: String) async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            bibleContent = try await bibleRepository.getBibleContent(versionId: versionId)
            self.version = version
            isLoadingSuccess = true
        } catch {
            print("Error fetching Bible content: \(error)")
        }
    }
    
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
}
