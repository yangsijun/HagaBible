//
//  BibleReferenceResolver.swift
//  HagaBible
//
//  Pure, offline resolution of a free-text Bible reference into a canonical
//  (bookCode, chapter, verse). Reuses the same parser + alias tables the in-app
//  search uses (`BibleReferenceParser`, `BibleBookReference`) but touches no DB and
//  no DI, so App Intents can call it from any process. Book resolution is
//  version-independent (canonical OSIS book code shared across every translation).
//

import Foundation

enum BibleReferenceResolver {
    struct Resolved: Equatable {
        let bookCode: String
        let chapter: Int
        let verse: Int
    }

    /// Resolves e.g. "요한복음 3장 16절", "John 3:16", "gen 1", "롬" into a canonical
    /// book code plus chapter/verse (defaulting missing chapter/verse to 1). Returns
    /// `nil` only when the book token can't be matched at all.
    static func resolve(_ text: String) -> Resolved? {
        let parsed = BibleReferenceParser.parse(text)
        let bookQuery = parsed.book.trimmingCharacters(in: .whitespaces)
        guard !bookQuery.isEmpty else { return nil }

        // Exact cross-language alias first (요한복음 / John / Jhn / 요), then a loose
        // prefix/substring match (창세 → GEN) as a last resort — mirroring the in-app
        // reference search, minus the version-specific DB abbreviation step which needs
        // a loaded version.
        guard let bookCode = BibleBookReference.bookCode(for: bookQuery)
            ?? BibleBookReference.looseBookCodes(for: bookQuery).first else {
            return nil
        }

        return Resolved(bookCode: bookCode, chapter: parsed.chapter ?? 1, verse: parsed.verse ?? 1)
    }
}
