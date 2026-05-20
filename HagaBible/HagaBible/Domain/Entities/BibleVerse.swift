//
//  BibleVerse.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

struct BibleVerse: Equatable, Hashable, Sendable {
    let bookCode: String
    let bookName: String
    let bookOrder: Int
    let chapter: Int
    let verse: Int
    let verseText: String?
    let versionCode: String
}

extension BibleVerse: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookCode = try container.decode(String.self, forKey: .bookCode)
        bookName = try container.decode(String.self, forKey: .bookName)
        bookOrder = try container.decode(Int.self, forKey: .bookOrder)
        chapter = try container.decode(Int.self, forKey: .chapter)
        verse = try container.decode(Int.self, forKey: .verse)
        verseText = try container.decodeIfPresent(String.self, forKey: .verseText)
        versionCode = try container.decode(String.self, forKey: .versionCode)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookCode, forKey: .bookCode)
        try container.encode(bookName, forKey: .bookName)
        try container.encode(bookOrder, forKey: .bookOrder)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(verse, forKey: .verse)
        try container.encodeIfPresent(verseText, forKey: .verseText)
        try container.encode(versionCode, forKey: .versionCode)
    }

    private enum CodingKeys: String, CodingKey {
        case bookCode, bookName, bookOrder, chapter, verse, verseText, versionCode
    }
}

extension Sequence where Element == BibleVerse {
    /// Joins the text of verses within `[startVerse, endVerse]`, in ascending verse order.
    func combinedText(startVerse: Int, endVerse: Int) -> String {
        filter { $0.verse >= startVerse && $0.verse <= endVerse }
            .sorted { $0.verse < $1.verse }
            .compactMap { $0.verseText }
            .joined(separator: " ")
    }
}
