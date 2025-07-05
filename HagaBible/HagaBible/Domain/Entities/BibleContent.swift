//
//  BibleContent.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

struct BibleContent: Codable, Identifiable {
    let id: String
    let version: String
    var books: [Book] = []
}

struct Book: Codable, Identifiable {
    let id: String
    let book: String
    let bookOrder: Int
    let bookName: String
    let version: String
    let totalChapters: Int
    var chapters: [Chapter] = []
}

struct Chapter: Codable, Identifiable {
    let id: String
    let book: String
    let chapter: Int
    let version: String
    let totalVerses: Int
    var verses: [Verse] = []
}

struct Verse: Codable, Identifiable {
    let id: String
    let canonOrder: String
    let book: String
    let chapter: Int
    let verse: Int
    let version: String
    let text: String
}
