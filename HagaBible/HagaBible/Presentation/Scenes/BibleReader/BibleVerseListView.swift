//
//  BibleVerseListView.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleVerseListView: View {
    let verses: [Verse]?
    let fontConfiguration: FontConfiguration
    var navigatedVerseNum: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(0)
            VStack(spacing: 0) {
                if let verses {
                    ForEach(0..<verses.count, id: \.self) { index in
                        BibleVerseView(
                            verseNumber: index + 1,
                            verseText: verses[index].text,
                            font: getUIFontFromFontConfiguration(fontConfiguration)
                        )
                        .id(index + 1)
                        .padding(.vertical, 8)
                        .background(
                            navigatedVerseNum == index + 1 ? Color.mint.opacity(0.25) : Color.clear
                        )
                    }
                } else {
                    ProgressView()
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
        }
    }
}

#Preview {
    let verses: [Verse] = [
        Verse(id: "GN1_1_WEBBE", canonOrder: "002_001_001", book: "GEN", chapter: 1, verse: 1, version: "WEBBE", text: "In the beginning, God created the heavens and the earth."),
        Verse(id: "GN1_2_WEBBE", canonOrder: "002_001_002", book: "GEN", chapter: 1, verse: 2, version: "WEBBE", text: "The earth was formless and empty. Darkness was on the surface of the deep and God’s Spirit was hovering over the surface of the waters."),
        Verse(id: "GN1_3_WEBBE", canonOrder: "002_001_003", book: "GEN", chapter: 1, verse: 3, version: "WEBBE", text: "God said, “Let there be light,” and there was light."),
    ]
    
    return BibleVerseListView(
        verses: verses,
        fontConfiguration: FontConfiguration(type: .sans, style: .regular, size: 17),
        navigatedVerseNum: 1
    )
}
