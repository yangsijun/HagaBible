//
//  BibleChapter.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

struct BibleChapter: Equatable, Hashable {
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let totalVerses: Int
    let versionCode: String
}
