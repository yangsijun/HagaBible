//
//  BibleReaderToolbarContent.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleReaderToolbarContent: ToolbarContent {
    let bookName: String?
    let chapterNum: Int
    let bibleVersion: BibleVersion?
    @Binding var showBibleNavigation: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
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
            }
        }
        ToolbarItem {
            Button(action: {}) {
                Image(systemName: "headphones")
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Menu {
                Menu {
//                                Picker(selection: $selectedVersion, label: Text("Sorting options")) {
//                                    Text("WEBBE").tag("WEBBE")
//                                    Text("KJV").tag("KJV")
//                                    Text("NIV").tag("NIV")
//                                }
                } label: {
                    Label("Versions", systemImage: "books.vertical")
                }
                Button(action: {}) {
                    Label("Bookmarks", systemImage: "bookmark")
                }
                Button(action: {}) {
                    Label("Font & Themes", systemImage: "textformat.size")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("View")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                BibleReaderToolbarContent(
                    bookName: "Genesis",
                    chapterNum: 1,
                    bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", language: "Korean"),
                    showBibleNavigation: .constant(false)
                )
            }
    }
}
