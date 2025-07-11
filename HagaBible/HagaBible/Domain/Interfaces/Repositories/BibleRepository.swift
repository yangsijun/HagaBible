//
//  BibleRepository.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

protocol BibleRepository {
    func fetchBibleVersionList() throws -> [BibleVersion]
    func fetchBibleBookList(versionCode: String) throws -> [BibleBook]
    func fetchBibleChapterList(versionCode: String, bookCode: String) throws -> [BibleChapter]
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapter: Int) throws -> [BibleVerse]
    func fetchBibleVerse(versionCode: String, bookCode: String, chapter: Int, verse: Int) throws -> BibleVerse?
    func findByVerseTextContaining(versionCode: String, keyword: String) throws -> [BibleVerse]
}
