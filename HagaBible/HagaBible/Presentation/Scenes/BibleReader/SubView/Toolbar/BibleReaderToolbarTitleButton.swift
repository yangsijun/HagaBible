//
//  BibleReaderToolbarTitleButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

struct BibleReaderToolbarTitleButton: View {
    let bookName: String?
    let chapterNum: Int
    let bibleVersion: BibleVersion?
    @Binding var showBibleNavigation: Bool
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                HStack {
                    Text("\(bookName ?? "") \(chapterNum)\(bibleVersion?.language == "Korean" ? "장" : "")")
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
                    Text("\(bookName ?? "") \(chapterNum)\(bibleVersion?.language == "Korean" ? "장" : "")")
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
            bookName: "Genesis",
            chapterNum: 1,
            bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", language: "Korean"),
            showBibleNavigation: .constant(false)
        )
    }
}
