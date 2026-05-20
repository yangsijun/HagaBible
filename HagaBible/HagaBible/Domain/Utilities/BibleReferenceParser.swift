//
//  BibleReferenceParser.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation

enum BibleReferenceParser {
    struct Components: Equatable {
        let book: String
        let chapter: Int?
        let verse: Int?
    }

    static func parse(_ input: String) -> Components {
        let pattern = #"^(.+?)\s*(?:(\d+)(?:[:장]\s*(\d+)?[절]?)?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return Components(book: input, chapter: nil, verse: nil)
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        if let match = regex.firstMatch(in: input, options: [], range: range) {
            let book = Range(match.range(at: 1), in: input).map { String(input[$0]) } ?? ""
            let chapter = Range(match.range(at: 2), in: input).flatMap { Int(input[$0]) }
            let verse = Range(match.range(at: 3), in: input).flatMap { Int(input[$0]) }
            return Components(book: book, chapter: chapter, verse: verse)
        }
        return Components(book: input, chapter: nil, verse: nil)
    }
}
