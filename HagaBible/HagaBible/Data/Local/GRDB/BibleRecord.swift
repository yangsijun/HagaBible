//
//  BibleRecord.swift
//  HagaBible
//
//  Created by 양시준 on 7/10/25.
//

// Database - GRDB
//import GRDB
//
//struct BibleVersionRecord: Codable, FetchableRecord, PersistableRecord {
//    let versionCode: String
//    let versionName: String
//    let language: String
//}
//
//struct BibleBookRecord: Codable, FetchableRecord, PersistableRecord {
//    let bookCode: String
//    let bookName: String
//    let bookOrder: Int
//    let totalChapters: Int
//    let versionCode: String
//}
//
//struct BibleChapterRecord: Codable, FetchableRecord, PersistableRecord {
//    let bookCode: String
//    let bookOrder: Int
//    let chapter: Int
//    let totalVerses: Int
//    let versionCode: String
//}
//
//struct BibleVerseRecord: Codable, FetchableRecord, PersistableRecord {
//    let bookCode: String
//    let bookName: String
//    let bookOrder: Int
//    let chapter: Int
//    let verse: Int
//    let verseText: String?
//    let versionCode: String
//}
