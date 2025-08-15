//
//  BibleVerseListView.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleVerseListView: View {
    let verses: [BibleVerse]
    let language: String
    let fontConfiguration: FontConfiguration
    var highlightedVerseNum: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(0)
            VStack(spacing: CGFloat(fontConfiguration.lineSpacing)) {
                ForEach(0..<verses.count, id: \.self) { index in
                    BibleVerseView(
                        verseNumber: index + 1,
                        verseText: verses[index].verseText ?? "",
                        font: getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: CGFloat(fontConfiguration.size)),
                        alignment: fontConfiguration.alignment[language] ?? .natural,
                        lineSpacing: CGFloat(fontConfiguration.lineSpacing)
                    )
                    .id(index + 1)
                    .padding(8)
                    .padding(.horizontal, 8)
                    .background(
                        highlightedVerseNum == index + 1 ? Color.orange.opacity(0.25) : .clear
                    )
                }
            }
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    let verses: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    
     BibleVerseListView(
        verses: verses,
        language: "Korean",
        fontConfiguration: FontConfiguration(
            type: [
                "English": .sans,
                "Korean": .serif,
            ],
            style: .regular,
            size: 17,
            alignment: [
                "English": .natural,
                "Korean": .justified
            ]
        ),
        highlightedVerseNum: 1
    )
}
