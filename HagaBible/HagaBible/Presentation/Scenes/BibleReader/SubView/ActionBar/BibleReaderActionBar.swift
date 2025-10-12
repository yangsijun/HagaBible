//
//  BibleReaderActionBar.swift
//  HagaBible
//
//  Created by 양시준 on 10/12/25.
//

import SwiftUI

struct BibleReaderActionBar: View {
    @Binding var selectStartIndex: Int?
    @Binding var selectEndIndex: Int?
    var bookName: String
    var chapterNum: Int
    var bibleVerseList: [BibleVerse] = []
    
    var body: some View {
        if selectStartIndex != nil || selectEndIndex != nil {
            HStack {
                Spacer()
                Button(action: {
                    copyVerseTextToClipboard()
                }) {
                    Circle()
                        .foregroundStyle(.clear)
                        .overlay(
                            Image(systemName: "doc.on.doc")
                        )
                        .glassEffect(in: .circle)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .clipShape(.circle)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
        }
    }
    
    private func copyVerseTextToClipboard() {
        let start = selectStartIndex ?? 0
        let end = selectEndIndex ?? start
        
        let referenceString = start == end
        ? "[\(bookName) \(chapterNum):\(start + 1)]"
        : "[\(bookName) \(chapterNum):\(start + 1)-\(end + 1)]"
        
        let verseLines: [String] = Array(start...end).map { idx in
            "\(idx + 1) \(bibleVerseList[idx].verseText ?? "")"
        }
        let lines = [referenceString] + verseLines
        let text = lines.joined(separator: "\n")
        UIPasteboard.general.string = text
        
        selectStartIndex = nil
        selectEndIndex = nil
    }
}

