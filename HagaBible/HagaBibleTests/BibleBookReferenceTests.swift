//
//  BibleBookReferenceTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
@testable import HagaBible

@Suite("BibleBookReference cross-language resolution")
struct BibleBookReferenceTests {

    @Test("English full names and abbreviations resolve to the canonical code")
    func test_englishResolves() {
        #expect(BibleBookReference.bookCode(for: "Genesis") == "GEN")
        #expect(BibleBookReference.bookCode(for: "Gen") == "GEN")
        #expect(BibleBookReference.bookCode(for: "Gn") == "GEN")
        #expect(BibleBookReference.bookCode(for: "Revelation") == "REV")
        #expect(BibleBookReference.bookCode(for: "John") == "JHN")
    }

    @Test("Korean full names and abbreviations resolve to the canonical code")
    func test_koreanResolves() {
        #expect(BibleBookReference.bookCode(for: "창세기") == "GEN")
        #expect(BibleBookReference.bookCode(for: "창") == "GEN")
        #expect(BibleBookReference.bookCode(for: "요한계시록") == "REV")
        #expect(BibleBookReference.bookCode(for: "요한복음") == "JHN")
    }

    @Test("the parsed book token from a full reference resolves regardless of language")
    func test_parsedTokenResolves() {
        // Mirrors how SearchViewModel feeds BibleReferenceParser output into the resolver.
        let english = BibleReferenceParser.parse("Gen 1:1")
        #expect(BibleBookReference.bookCode(for: english.book) == "GEN")

        let korean = BibleReferenceParser.parse("창세기 1장 1절")
        #expect(BibleBookReference.bookCode(for: korean.book) == "GEN")
    }

    @Test("a numbered-book token still carrying a space after parsing resolves")
    func test_parsedNumberedBookResolves() {
        // The parser yields "1 Sam" (space preserved) for this input; the resolver's
        // whitespace-stripping normalization must still match the "1sam" alias.
        let parsed = BibleReferenceParser.parse("1 Sam 3:1")
        #expect(BibleBookReference.bookCode(for: parsed.book) == "1SA")

        let parsedJohn = BibleReferenceParser.parse("1 John 4:8")
        #expect(BibleBookReference.bookCode(for: parsedJohn.book) == "1JN")
    }

    @Test("every canonical OSIS code resolves to itself (66-book completeness guard)")
    func test_allCanonicalCodesResolve() {
        let codes = [
            "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
            "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
            "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
            "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT",
            "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP",
            "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE",
            "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
        ]
        #expect(codes.count == 66)
        for code in codes {
            #expect(BibleBookReference.bookCode(for: code) == code, "\(code) should resolve to itself")
        }
    }

    @Test("numbered books with internal spaces resolve")
    func test_numberedBooks() {
        #expect(BibleBookReference.bookCode(for: "1 Samuel") == "1SA")
        #expect(BibleBookReference.bookCode(for: "1Samuel") == "1SA")
        #expect(BibleBookReference.bookCode(for: "1 John") == "1JN")
        #expect(BibleBookReference.bookCode(for: "삼상") == "1SA")
        #expect(BibleBookReference.bookCode(for: "요일") == "1JN")
    }

    @Test("matching is case-insensitive and whitespace-tolerant")
    func test_normalization() {
        #expect(BibleBookReference.bookCode(for: "  GENESIS  ") == "GEN")
        #expect(BibleBookReference.bookCode(for: "rEv") == "REV")
        #expect(BibleBookReference.bookCode(for: "Song of Solomon") == "SNG")
    }

    @Test("the canonical book code itself is accepted")
    func test_canonicalCodeAccepted() {
        #expect(BibleBookReference.bookCode(for: "PSA") == "PSA")
        #expect(BibleBookReference.bookCode(for: "exo") == "EXO")
        #expect(BibleBookReference.bookCode(for: "mrk") == "MRK")
    }

    @Test("unknown tokens return nil")
    func test_unknownReturnsNil() {
        #expect(BibleBookReference.bookCode(for: "") == nil)
        #expect(BibleBookReference.bookCode(for: "NotABook") == nil)
        #expect(BibleBookReference.bookCode(for: "123") == nil)
    }

    // MARK: - Loose partial / substring matching

    @Test("a Korean prefix resolves to the book it begins")
    func test_loose_koreanPrefix() {
        #expect(BibleBookReference.looseBookCodes(for: "창세").first == "GEN")
        #expect(BibleBookReference.looseBookCodes(for: "여호").first == "JOS")
        #expect(BibleBookReference.looseBookCodes(for: "요한복").first == "JHN")
    }

    @Test("an English prefix resolves to the book it begins")
    func test_loose_englishPrefix() {
        #expect(BibleBookReference.looseBookCodes(for: "genes").first == "GEN")
        #expect(BibleBookReference.looseBookCodes(for: "reve").first == "REV")
        #expect(BibleBookReference.looseBookCodes(for: "philipp").first == "PHP")
    }

    @Test("an ambiguous prefix lists every match in canonical order, best first")
    func test_loose_ambiguousOrdering() {
        // 고린도전서(1CO) precedes 고린도후서(2CO).
        #expect(BibleBookReference.looseBookCodes(for: "고린") == ["1CO", "2CO"])

        // Every "요한…" book in canonical order: 요한복음(43) → 요한일서(62) →
        // 요한이서(63) → 요한삼서(64) → 요한계시록(66). The reader preview takes
        // `.first`, so an ambiguous "요한" still resolves to 요한복음.
        #expect(BibleBookReference.looseBookCodes(for: "요한") == ["JHN", "1JN", "2JN", "3JN", "REV"])
        #expect(BibleBookReference.looseBookCodes(for: "요한").first == "JHN")
        #expect(BibleBookReference.looseBookCodes(for: "고린").first == "1CO")
    }

    @Test("an exact alias short-circuits loose matching to a single book")
    func test_loose_exactWins() {
        // "창" is an exact abbreviation; it must not also drag in 창세기 as a tie.
        #expect(BibleBookReference.looseBookCodes(for: "창") == ["GEN"])
        #expect(BibleBookReference.looseBookCodes(for: "genesis") == ["GEN"])
    }

    @Test("a clean prefix query lists only its books in order")
    func test_loose_prefixGroup() {
        // 데살로니가전서(1TH) and 데살로니가후서(2TH) both begin with "데살".
        #expect(BibleBookReference.looseBookCodes(for: "데살") == ["1TH", "2TH"])
    }

    @Test("a mid-word fragment still resolves via substring matching")
    func test_loose_substringMatch() {
        // No alias begins with "사야", but 이사야 contains it.
        #expect(BibleBookReference.looseBookCodes(for: "사야").first == "ISA")
    }

    @Test("queries shorter than the minimum only honor exact matches")
    func test_loose_minimumLength() {
        // Single Korean syllable that is NOT an alias: no loose explosion.
        #expect(BibleBookReference.looseBookCodes(for: "느").isEmpty == false) // 느 → 느헤미야? exact
        // A one-character non-alias returns nothing rather than every match.
        #expect(BibleBookReference.looseBookCodes(for: "ㄱ").isEmpty)
    }

    @Test("loose matching returns empty for unknown tokens")
    func test_loose_unknownEmpty() {
        #expect(BibleBookReference.looseBookCodes(for: "Zzzz").isEmpty)
        #expect(BibleBookReference.looseBookCodes(for: "").isEmpty)
    }

    @Test("the parser book token feeds loose matching for partial references")
    func test_loose_parsedPartialReference() {
        let parsed = BibleReferenceParser.parse("창세 1:1")
        #expect(BibleBookReference.looseBookCodes(for: parsed.book).first == "GEN")

        let english = BibleReferenceParser.parse("philipp 4:13")
        #expect(BibleBookReference.looseBookCodes(for: english.book).first == "PHP")
    }
}
