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
}
