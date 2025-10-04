//
//  BibleVerse.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

struct BibleVerse: Equatable, Hashable, Codable {
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let verse: Int
    let verseText: String?
    let versionCode: String
}
