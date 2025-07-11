//
//  BibleVerseRecord.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

// Database - GRDB
import GRDB

struct BibleVerseRecord: Codable, FetchableRecord, PersistableRecord {
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let verse: Int
    let verseText: String?
    let versionCode: String
    
    private enum CodingKeys: String, CodingKey {
        case bookCode = "book_code"
        case bookOrder = "book_order"
        case chapter = "chapter"
        case verse = "verse"
        case verseText = "verse_text"
        case versionCode = "version_code"
    }
}
