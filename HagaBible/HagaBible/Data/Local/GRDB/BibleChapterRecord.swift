//
//  BibleChapterRecord.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

// Database - GRDB
import GRDB

struct BibleChapterRecord: Codable, FetchableRecord, PersistableRecord {
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let totalVerses: Int
    let versionCode: String
    
    private enum CodingKeys: String, CodingKey {
        case bookCode = "book_code"
        case bookOrder = "book_order"
        case chapter = "chapter"
        case totalVerses = "total_verses"
        case versionCode = "version_code"
    }
}
