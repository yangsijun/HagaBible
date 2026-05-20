//
//  BibleReferenceFormatter.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

enum BibleReferenceFormatter {
    /// Formats a verse reference as "Book chapter:verse" or "Book chapter:start-end".
    static func reference(book: String, chapter: Int, startVerse: Int, endVerse: Int) -> String {
        if startVerse == endVerse {
            return "\(book) \(chapter):\(startVerse)"
        } else {
            return "\(book) \(chapter):\(startVerse)-\(endVerse)"
        }
    }

    static func reference(book: String, for bookmark: Bookmark) -> String {
        reference(book: book, chapter: bookmark.chapter, startVerse: bookmark.startVerse, endVerse: bookmark.endVerse)
    }
}
