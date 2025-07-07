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
    let version: BibleVersion?
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {}) {
                HStack {
                    Text("\(bookName ?? "") \(chapterNum)\(version?.language == "ko-KR" ? "장" : "")")
                        .font(.title2)
                        .bold()
                    Text("\(version?.id ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } // HStack
                .padding(.vertical, 8)
            } // Button
        } // ToolbarItem
        ToolbarItem {
            Button(action: {}) {
                Image(systemName: "headphones")
            } // Button
        } // ToolbarItem
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
                } // Menu
                Button(action: {}) {
                    Label("Bookmarks", systemImage: "bookmark")
                } // Button
                Button(action: {}) {
                    Label("Font & Themes", systemImage: "textformat.size")
                } // Button
            } label: {
                Image(systemName: "ellipsis")
            } // Menu
        } // ToolbarItem
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
                    version: .init(id: "WEBBE", language: "en-GB", name: "WEBBE", isDownloaded: true)
                )
            }
    } // NavigationStack
}
