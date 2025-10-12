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
    @Binding var showFontThemeConfig: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            BibleReaderToolbarTitleButton(
                bookName: bookName,
                chapterNum: chapterNum,
                bibleVersion: bibleVersion,
                showBibleNavigation: $showBibleNavigation
            )
        }
        ToolbarItem {
            BibleReaderToolbarIconButton(action: {}) {
                Label("Listen", systemImage: "headphones")
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }
        ToolbarItem {
            BibleReaderToolbarMenuButton(
                menuItems: [
                    MenuItem(title: "Bookmarks", systemImage: "bookmark", action: {}),
                    MenuItem(title: "Font & Themes", systemImage: "textformat.size", action: {
                        showFontThemeConfig.toggle()
                    })
                ]
            ) {
                Label("Other", systemImage: "ellipsis")
            }
        }
    }
}

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
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
                    showBibleNavigation: .constant(false),
                    showFontThemeConfig: .constant(false)
                )
            }
    }
}
