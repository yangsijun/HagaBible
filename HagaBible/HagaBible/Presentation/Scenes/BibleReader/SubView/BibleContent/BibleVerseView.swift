//
//  BibleVerseView.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import SwiftUI

struct BibleVerseView: View {
    /// Body font size the verse-number metrics are tuned around. The verse number
    /// scales proportionally to the reader's font size relative to this base, so it
    /// grows/shrinks roughly in step with the verse text (≈ caption size at the base).
    static let baseBodyFontSize: CGFloat = 20
    /// Minimum width of the leading verse-number column at `baseBodyFontSize`.
    static let baseVerseNumberColumnWidth: CGFloat = 12
    /// Spacing between the verse number and the verse text.
    static let verseNumberSpacing: CGFloat = 8

    /// Verse-number column min-width scaled for a given body font size, so callers
    /// (e.g. the compare-view inset) can align with the same proportional column.
    static func verseNumberColumnWidth(forBodyFontSize bodyFontSize: CGFloat) -> CGFloat {
        baseVerseNumberColumnWidth * bodyFontSize / baseBodyFontSize
    }

    let verseNumber: Int
    let verseText: String

    private var font: UIFont
    private var textColor: UIColor
    private var verseNumberColor: UIColor
    private var alignment: NSTextAlignment
    private var lineSpacing: CGFloat?

    private var verseFontWidth: Font.Width

    /// Verse-number metrics, scaled in `init` from the body font size around
    /// `baseBodyFontSize` (caption-ish at the base, larger with bigger reader fonts).
    private var verseNumberFontSize: CGFloat
    private var verseNumberMinWidth: CGFloat
    private var verseNumberMinHeight: CGFloat

    init(
        verseNumber: Int,
        verseText: String,
        font: UIFont? = nil,
        textColor: UIColor = .label,
        verseNumberColor: UIColor = .secondaryLabel,
        alignment: NSTextAlignment = .natural,
        lineSpacing: CGFloat? = nil
    ) {
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.font = font ?? .systemFont(ofSize: 17)
        self.textColor = textColor
        self.verseNumberColor = verseNumberColor
        self.alignment = alignment
        self.lineSpacing = lineSpacing

        if verseNumber < 10 {
            self.verseFontWidth = .standard
        } else if verseNumber < 100 {
            self.verseFontWidth = .condensed
        } else {
            self.verseFontWidth = .compressed
        }

        // Scale the verse number roughly in proportion to the body font size, so it
        // tracks the reader's font-size setting instead of staying a fixed caption.
        let scale = self.font.pointSize / Self.baseBodyFontSize
        self.verseNumberFontSize = 12 * scale
        self.verseNumberMinHeight = 22 * scale
        self.verseNumberMinWidth = Self.verseNumberColumnWidth(forBodyFontSize: self.font.pointSize)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Self.verseNumberSpacing) {
            Text("\(verseNumber)")
                .frame(minWidth: verseNumberMinWidth, minHeight: verseNumberMinHeight, alignment: .center)
                .font(.system(size: verseNumberFontSize))
                .fontWidth(verseFontWidth)
                .foregroundStyle(Color(uiColor: verseNumberColor))
            AdvancedText(
                attributedText: NSMutableAttributedString(
                    string: verseText,
                    attributes: [
                        .font: font,
                        .foregroundColor: textColor,
                        .paragraphStyle: {
                            let style = NSMutableParagraphStyle()
                            style.alignment = alignment
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
            textColor: .red,
            alignment: .justified
        )
        BibleVerseView(verseNumber: 88, verseText: "In the beginning, God created the heavens and the earth.")
        BibleVerseView(verseNumber: 118, verseText: "In the beginning, God created the heavens and the earth.")
    }
    .padding(8)
}
