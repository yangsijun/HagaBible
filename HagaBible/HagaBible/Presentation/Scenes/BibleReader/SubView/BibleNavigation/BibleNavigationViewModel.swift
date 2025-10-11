//
//  BibleNavigationViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 10/12/25.
//

import Observation

@Observable
@MainActor
class BibleNavigationViewModel {
    var bibleRepository: BibleRepository
    
    var versionList: [BibleVersion] = []
    var bookList: [BibleBook] = []
    var chapterList: [BibleChapter] = []
    var verseList: [BibleVerse] = []
    
    init(bibleRepository: BibleRepository) {
        self.bibleRepository = bibleRepository
    }
    
    func loadVersionList() async {
        do {
            versionList = try await bibleRepository.fetchBibleVersionList()
        } catch {
            versionList = []
        }
    }

    func loadBookList(version: BibleVersion) async {
        do {
            bookList = try await bibleRepository.fetchBibleBookList(versionCode: version.versionCode)
        } catch {
            bookList = []
        }
    }

    func loadChapterList(version: BibleVersion, book: BibleBook) async {
        do {
            chapterList = try await bibleRepository.fetchBibleChapterList(versionCode: version.versionCode, bookCode: book.bookCode)
        } catch {
            chapterList = []
        }
    }

    func loadVerseList(version: BibleVersion, book: BibleBook, chapter: BibleChapter) async {
        do {
            verseList = try await bibleRepository.fetchBibleVerseList(versionCode: version.versionCode, bookCode: book.bookCode, chapter: chapter.chapter)
        } catch {
            verseList = []
        }
    }
}
