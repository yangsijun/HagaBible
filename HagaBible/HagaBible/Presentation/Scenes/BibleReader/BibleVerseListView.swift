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
    
    var body: some View {
        VStack(spacing: 0) {
            if let verses {
                ForEach(0..<verses.count, id: \.self) { index in
                    BibleVerseView(
                        verseNumber: index + 1,
                        verseText: verses[index].text,
                        font: getUIFontFromFontConfiguration(fontConfiguration)
                    )
                    .padding(.vertical, 8)
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var verses: [Verse]?
        
        var body: some View {
            BibleVerseListView (
                verses: verses,
                fontConfiguration: FontConfiguration(type: .sans, style: .regular, size: 17)
            )
                .task {
                    do {
                        verses = try await MockBibleRepositoryImpl().getChapter(bookNum: 1, chapter: 1, versionId: "WEBBE").verses
                    } catch {
                        verses = nil
                    }
                }
        }
    }
    return PreviewWrapper()
}
