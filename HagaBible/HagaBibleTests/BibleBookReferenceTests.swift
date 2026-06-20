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
}
