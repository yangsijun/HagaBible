//
//  BibleVerseView.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import SwiftUI

struct BibleVerseView: View {
    var verseNumber: Int
    var verseText: String
    var font: UIFont
    var fontWidth: Font.Width
    var alignment: NSTextAlignment = .natural
    var lineBreakMode: NSLineBreakMode = .byWordWrapping
    
    init(
        verseNumber: Int,
        verseText: String,
        font: UIFont? = nil,
        alignment: NSTextAlignment = .natural,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.font = font ?? .systemFont(ofSize: 17)
        if verseNumber < 10 {
            self.fontWidth = .standard
        } else if verseNumber < 100 {
            self.fontWidth = .condensed
        } else {
            self.fontWidth = .compressed
        }
        self.alignment = alignment
        self.lineBreakMode = lineBreakMode
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(verseNumber)")
                .frame(minWidth: 12, minHeight: 22, alignment: .center)
                .font(.caption)
                .fontWidth(fontWidth)
                .foregroundStyle(.secondary)
            AdvancedTextView(verseText, font: font, alignment: alignment, lineBreakMode: lineBreakMode)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    VStack {
        BibleVerseView(
            verseNumber: 1,
            verseText: "In the beginning, God created the heavens and the earth.",
            font: .pretendard(size: 17)
        )
        BibleVerseView(
            verseNumber: 1,
            verseText: "In the beginning, God created the heavens and the earth.",
            font: .pretendard(size: 17)
        )
        BibleVerseView(
            verseNumber: 1,
            verseText: "In the beginning, God created the heavens and the earth.",
            font: .maruBuri(size: 17)
        )
        BibleVerseView(
            verseNumber: 4,
            verseText: "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            font: .pretendard(size: 17),
            alignment: .justified,
            lineBreakMode: .byCharWrapping
        )
        BibleVerseView(
            verseNumber: 4,
            verseText: "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            font: .maruBuri(size: 17),
            alignment: .justified,
            lineBreakMode: .byCharWrapping
        )
        BibleVerseView(verseNumber: 88, verseText: "In the beginning, God created the heavens and the earth.")
        BibleVerseView(verseNumber: 118, verseText: "In the beginning, God created the heavens and the earth.")
    }
    .padding(8)
}
