//
//  BibleReaderToolbarTitleButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

struct BibleReaderToolbarTitleButton: View {
    let bibleBook: BibleBook?
    let chapterNum: Int
    let bibleVersion: BibleVersion?
    
    var chapterCounterNoun: String {
        getChapterCounterNoun(bookCode: bibleBook?.bookCode ?? "", versionLanguage: bibleVersion?.language ?? "")
    }
    
    @Binding var showBibleNavigation: Bool
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                HStack {
                    Text("\(bibleBook?.bookName ?? "") \(chapterNum)\(chapterCounterNoun)")
                        .font(.title2)
                        .bold()
                    Text("\(bibleVersion?.versionCode ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color(.label))
                .padding(.vertical, 8)
            }
        } else {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                HStack {
                    Text("\(bibleBook?.bookName ?? "") \(chapterNum)\(chapterCounterNoun)")
                        .font(.title2)
                        .bold()
                    Text("\(bibleVersion?.versionCode ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .toolbarButtonStyle(.capsule)
        }
    }
}

#Preview {
    ZStack {
        BibleReaderToolbarTitleButton(
            bibleBook: .init(bookCode: "GEN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
            chapterNum: 1,
            bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
            showBibleNavigation: .constant(false)
        )
    }
}
