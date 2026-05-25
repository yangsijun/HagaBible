//
//  BibleCompareVerseView.swift
//  HagaBible
//
//  Created by 양시준 on 5/22/26.
//

import SwiftUI

/// Renders a single comparison-translation verse beneath the main verse text:
/// smaller, in a subdued gray, and without a verse number of its own. The number
/// belongs to the main verse it sits under (역본 대조 보기).
struct BibleCompareVerseView: View {
    let verseText: String
    let font: UIFont
    let textColor: UIColor
    let alignment: NSTextAlignment
    let lineSpacing: CGFloat?

    var body: some View {
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

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        BibleVerseView(
            verseNumber: 1,
            verseText: "태초에 하나님이 천지를 창조하시니라",
            font: .maruBuri(size: 17),
            alignment: .justified
        )
        BibleCompareVerseView(
            verseText: "In the beginning, God created the heavens and the earth.",
            font: .pretendard(size: 14),
            textColor: UIColor.label.withAlphaComponent(0.6),
            alignment: .natural,
            lineSpacing: 4
        )
        .padding(.leading, 20)
    }
    .padding()
}
