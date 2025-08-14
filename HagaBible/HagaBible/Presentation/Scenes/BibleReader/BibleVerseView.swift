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
    
    private var font: UIFont
    private var alignment: NSTextAlignment
    private var lineHeight: CGFloat?
    private var lineSpacing: CGFloat?
    
    private var verseFontWidth: Font.Width
    
    init(
        verseNumber: Int,
        verseText: String,
        font: UIFont? = nil,
        alignment: NSTextAlignment = .natural,
        lineHeight: CGFloat? = nil,
        lineSpacing: CGFloat? = nil
    ) {
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.font = font ?? .systemFont(ofSize: 17)
        self.alignment = alignment
        self.lineHeight = lineHeight
        self.lineSpacing = lineSpacing
        
        if verseNumber < 10 {
            self.verseFontWidth = .standard
        } else if verseNumber < 100 {
            self.verseFontWidth = .condensed
        } else {
            self.verseFontWidth = .compressed
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(verseNumber)")
                .frame(minWidth: 12, minHeight: 22, alignment: .center)
                .font(.caption)
                .fontWidth(verseFontWidth)
                .foregroundStyle(.secondary)
            AdvancedText(
                attributedText: NSMutableAttributedString(
                    string: verseText,
                    attributes: [
                        .font: font,
                        .paragraphStyle: {
                            let style = NSMutableParagraphStyle()
                            style.alignment = alignment
                            if let lineHeight = lineHeight {
                                style.minimumLineHeight = lineHeight
                                style.maximumLineHeight = lineHeight
                            }
                            if let lineSpacing = lineSpacing {
                                style.lineSpacing = lineSpacing
                            }
                            return style
                        }(),
                    ]
                )
            )
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
            alignment: .justified
        )
        BibleVerseView(
            verseNumber: 4,
            verseText: "빛이 하나님이 보시기에 좋았더라 하나님이 빛과 어둠을 나누사",
            font: .maruBuri(size: 17),
            alignment: .justified
        )
        BibleVerseView(
            verseNumber: 14,
            verseText: "하나님이 가라사대 하늘의 궁창에 광명이 있어 주야를 나뉘게 하라 또 그 광명으로 하여 징조와 사시와 일자와 연한이 이루라",
            font: .maruBuri(size: 23),
            alignment: .justified
        )
        BibleVerseView(verseNumber: 88, verseText: "In the beginning, God created the heavens and the earth.")
        BibleVerseView(verseNumber: 118, verseText: "In the beginning, God created the heavens and the earth.")
    }
    .padding(8)
}
