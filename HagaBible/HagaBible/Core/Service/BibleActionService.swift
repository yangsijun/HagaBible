//
//  BibleActionService.swift
//  HagaBible
//
//  Created by 양시준 on 10/18/25.
//

import Foundation

@MainActor
@Observable
class BibleActionService {
    func makeVerseStringFromVerseList(_ verseList: [BibleVerse], start: Int = 0, end: Int = 0) -> String {
        var end = end
        if start > end {
            end = start
        }
        
        let bookName = verseList[start].bookName
        let chapterNum = verseList[start].chapter
        
        if start == end {
            let referenceString = "[\(bookName) \(chapterNum):\(start + 1)]"
            let verseText = "\(verseList[start].verseText ?? "")"
            let text = [referenceString, verseText].joined(separator: " ")
            
            return text
        }
        
        let referenceString = "[\(bookName) \(chapterNum):\(start + 1)-\(end + 1)]"
        let verseLines: [String] = Array(start...end).map { idx in
            "\(idx + 1) \(verseList[idx].verseText ?? "")"
        }
        let lines = [referenceString] + verseLines
        let text = lines.joined(separator: "\n")

        return text
    }

    /// Builds one version's export block. The reference header carries the version
    /// name only when `versionName` is non-nil/non-empty (used to tell the two
    /// blocks apart when exporting both versions), e.g. `[창세기 1:1, NKRV] 태초에 ...`;
    /// a single-version export passes `nil` and gets `[창세기 1:1] 태초에 ...`. Ranges
    /// emit a header line followed by `"<verse> <text>"` lines. Verses are selected
    /// by verse *number* (not index) so a comparison version with versification
    /// gaps simply contributes the verses it has; returns `nil` when none fall in
    /// the range.
    func makeVersionBlock(_ verses: [BibleVerse], startVerse: Int, endVerse: Int, versionName: String?) -> String? {
        let lo = min(startVerse, endVerse)
        let hi = max(startVerse, endVerse)
        let matched = verses
            .filter { $0.verse >= lo && $0.verse <= hi }
            .sorted { $0.verse < $1.verse }
        guard let first = matched.first, let last = matched.last else { return nil }

        // Use the actually-present verse numbers so the header never overstates the
        // range — a comparison version may be missing verses within the selection.
        let reference = BibleReferenceFormatter.reference(book: first.bookName, chapter: first.chapter, startVerse: first.verse, endVerse: last.verse)
        let header: String
        if let versionName, !versionName.isEmpty {
            header = "[\(reference), \(versionName)]"
        } else {
            header = "[\(reference)]"
        }

        if matched.count == 1 {
            return "\(header) \(first.verseText ?? "")"
        }
        let verseLines = matched.map { "\($0.verse) \($0.verseText ?? "")" }
        return ([header] + verseLines).joined(separator: "\n")
    }
}
