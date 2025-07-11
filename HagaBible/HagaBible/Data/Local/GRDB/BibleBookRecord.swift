//
//  BibleBookRecord.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

// Database - GRDB
import GRDB

struct BibleBookRecord: Codable, FetchableRecord, PersistableRecord {
    let bookCode: String
    let bookName: String
    let bookOrder: Int
    let totalChapters: Int
    let versionCode: String
    
    private enum CodingKeys: String, CodingKey {
        case bookCode = "book_code"
        case bookName = "book_name"
        case bookOrder = "book_order"
        case totalChapters = "total_chapters"
        case versionCode = "version_code"
    }
}
