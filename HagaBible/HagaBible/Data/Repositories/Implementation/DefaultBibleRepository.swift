//
//  DefaultBibleRepository.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

import Foundation
import GRDB

final class DefaultBibleRepository: BibleRepository {
    private let dbPool: DatabasePool
    
    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }
    
    func fetchBibleVersionList() async throws -> [BibleVersion] {
        let sql = """
            SELECT
                *
            FROM
                bible_version
            ORDER BY
                language, version_code;
        """
        
        return try await dbPool.read { db in
            let bibleVersionRecordList = try BibleVersionRecord.fetchAll(db, sql: sql, arguments: [])
            
            return bibleVersionRecordList.map {
                BibleVersion(
                    versionCode: $0.versionCode,
                    versionName: $0.versionName,
                    language: $0.language
                )
            }
        }
    }
    
    func fetchBibleBookList(versionCode: String) async throws -> [BibleBook] {
        let sql = """
            SELECT
                book_code,
                book_name,
                book_order,
                MAX(chapter) as total_chapters,
                version_code
            FROM
                bible_verse
            WHERE
                version_code = ?
            GROUP BY
                book_code, version_code
            ORDER BY
                book_order;
        """
        
        return try await dbPool.read { db in
            let bibleBookRecordList = try BibleBookRecord.fetchAll(db, sql: sql, arguments: [versionCode])
            
            return bibleBookRecordList.map {
                BibleBook(
                    bookCode: $0.bookCode,
                    bookName: $0.bookName,
                    bookOrder: $0.bookOrder,
                    totalChapters: $0.totalChapters,
                    versionCode: $0.versionCode
                )
            }
        }
    }
    
    func fetchBibleChapterList(versionCode: String, bookCode: String) async throws -> [BibleChapter] {
        let sql = """
            SELECT
                book_code,
                book_order,
                chapter,
                MAX(verse) AS total_verses,
                version_code
            FROM
                bible_verse
            WHERE
                version_code = ?
                AND book_code = ?
            GROUP BY
                book_code, chapter
            ORDER BY
                book_order, chapter;
        """
        
        return try await dbPool.read { db in
            let bibleChapterRecordList = try BibleChapterRecord.fetchAll(db, sql: sql, arguments: [versionCode, bookCode])
            
            return bibleChapterRecordList.map {
                BibleChapter(
                    bookCode: $0.bookCode,
                    bookOrder: $0.bookOrder,
                    chapter: $0.chapter,
                    totalVerses: $0.totalVerses,
                    versionCode: $0.versionCode
                )
            }
        }
    }
    
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapter: Int) async throws -> [BibleVerse] {
        let sql = """
            SELECT
                book_code,
                book_name,
                book_order,
                chapter,
                verse,
                verse_text,
                version_code
            FROM
                bible_verse
            WHERE
                version_code = ?
                AND book_code = ?
                AND chapter = ?
            ORDER BY
                book_order, chapter, verse;
        """
        
        return try await dbPool.read { db in
            let bibleVerseRecordList = try BibleVerseRecord.fetchAll(db, sql: sql, arguments: [versionCode, bookCode, chapter])
            
            return bibleVerseRecordList.map {
                BibleVerse(
                    bookCode: $0.bookCode,
                    bookName: $0.bookName,
                    bookOrder: $0.bookOrder,
                    chapter: $0.chapter,
                    verse: $0.verse,
                    verseText: $0.verseText,
                    versionCode: $0.versionCode
                )
            }
        }
    }
    
    func fetchBibleVerse(versionCode: String, bookCode: String, chapter: Int, verse: Int) async throws -> BibleVerse? {
        let sql = """
            SELECT
                book_code,
                book_name,
                book_order,
                chapter,
                verse,
                verse_text,
                version_code
            FROM
                bible_verse
            WHERE
                version_code = ?
                AND book_code = ?
                AND chapter = ?
                AND verse = ?
            ORDER BY
                book_order, chapter, verse;
        """
        
        return try await dbPool.read { db in
            let bibleVerseRecord = try BibleVerseRecord.fetchOne(db, sql: sql, arguments: [versionCode, bookCode, chapter, verse])
            
            return bibleVerseRecord.map {
                BibleVerse(
                    bookCode: $0.bookCode,
                    bookName: $0.bookName,
                    bookOrder: $0.bookOrder,
                    chapter: $0.chapter,
                    verse: $0.verse,
                    verseText: $0.verseText,
                    versionCode: $0.versionCode
                )
            }
        }
    }
    
    func findByVerseTextContaining(versionCode: String, keyword: String) async throws -> [BibleVerse] {
        let sql = """
            SELECT
                book_code,
                book_name,
                book_order,
                chapter,
                verse,
                verse_text,
                version_code
            FROM
                bible_verse
            WHERE
                version_code = ?
                AND LOWER(verse_text) LIKE LOWER(?)
            ORDER BY
                book_order, chapter, verse;
        """
        
        return try await dbPool.read { db in
            let bibleVerseRecordList = try BibleVerseRecord.fetchAll(db, sql: sql, arguments: [versionCode, "%\(keyword)%"])
            
            return bibleVerseRecordList.map {
                BibleVerse(
                    bookCode: $0.bookCode,
                    bookName: $0.bookName,
                    bookOrder: $0.bookOrder,
                    chapter: $0.chapter,
                    verse: $0.verse,
                    verseText: $0.verseText,
                    versionCode: $0.versionCode
                )
            }
        }
    }
}
