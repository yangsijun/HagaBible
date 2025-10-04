//
//  BibleBook.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

struct BibleBook: Equatable, Hashable, Codable {
    let bookCode: String
    let bookName: String
    let bookOrder: Int
    let totalChapters: Int
    let versionCode: String
}
