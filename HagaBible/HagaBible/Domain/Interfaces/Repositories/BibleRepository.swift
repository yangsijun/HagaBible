//
//  BibleRepository.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

protocol BibleRepository {
    func fetchBibleVersionList() async throws -> [BibleVersion]
    func fetchBibleBookList(versionCode: String) async throws -> [BibleBook]
    func fetchBibleChapterList(versionCode: String, bookCode: String) async throws -> [BibleChapter]
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapter: Int) async throws -> [BibleVerse]
    func fetchBibleVerse(versionCode: String, bookCode: String, chapter: Int, verse: Int) async throws -> BibleVerse?
    func findByVerseTextContaining(versionCode: String, keyword: String) async throws -> [BibleVerse]
    func findBookCodeByAbbreviation(versionCode: String, abbreviation: String) async throws -> String?
}
