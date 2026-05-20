//
//  BookmarkStripe.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import Foundation

struct BookmarkStripe: Equatable, Sendable {
    let color: BookmarkColor
    let extendsUp: Bool
    let extendsDown: Bool
}

enum BookmarkStripeComputer {
    static let columnLimit = 5

    /// Maps bookmarks to per-verse stripe columns. Keys are 1-indexed verse
    /// numbers; each value is a fixed-width column array where `nil` marks a gap.
    static func computeStripes(from bookmarks: [Bookmark]) -> [Int: [BookmarkStripe?]] {
        let sorted = bookmarks.sorted { lhs, rhs in
            if lhs.startVerse != rhs.startVerse { return lhs.startVerse < rhs.startVerse }
            if lhs.endVerse != rhs.endVerse { return lhs.endVerse < rhs.endVerse }
            return lhs.createdAt < rhs.createdAt
        }

        var columnByID: [UUID: Int] = [:]
        var maxEndVerseByColumn: [Int: Int] = [:]

        for bookmark in sorted {
            var col = 0
            while col < columnLimit {
                if let occupiedEnd = maxEndVerseByColumn[col], occupiedEnd >= bookmark.startVerse {
                    col += 1
                    continue
                }
                columnByID[bookmark.id] = col
                maxEndVerseByColumn[col] = max(maxEndVerseByColumn[col] ?? 0, bookmark.endVerse)
                break
            }
        }

        let totalColumns = (columnByID.values.max() ?? -1) + 1
        guard totalColumns > 0 else { return [:] }

        var result: [Int: [BookmarkStripe?]] = [:]
        for bookmark in sorted {
            guard let col = columnByID[bookmark.id] else { continue }
            for verse in bookmark.startVerse...bookmark.endVerse {
                if result[verse] == nil {
                    result[verse] = Array(repeating: nil, count: totalColumns)
                }
                let stripe = BookmarkStripe(
                    color: bookmark.color,
                    extendsUp: verse > bookmark.startVerse,
                    extendsDown: verse < bookmark.endVerse
                )
                result[verse]?[col] = stripe
            }
        }
        return result
    }
}
