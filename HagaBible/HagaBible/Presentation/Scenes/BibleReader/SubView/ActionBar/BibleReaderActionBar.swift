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
    var bibleVersesString: String {
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
        
        return text
    }
    
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
                
                ShareLink(
                    item: bibleVersesString
                ) {
                    Circle()
                        .foregroundStyle(.clear)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
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
        UIPasteboard.general.string = bibleVersesString
        
        selectStartIndex = nil
        selectEndIndex = nil
    }
}

#Preview {
    let bibleVerseList: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    BibleReaderActionBar(selectStartIndex: .constant(0), selectEndIndex: .constant(2), bookName: "창세기", chapterNum: 1, bibleVerseList: bibleVerseList)
}
