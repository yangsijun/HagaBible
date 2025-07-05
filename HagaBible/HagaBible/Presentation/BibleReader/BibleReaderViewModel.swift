//
//  BibleReaderViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

import Observation

@Observable
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
}
