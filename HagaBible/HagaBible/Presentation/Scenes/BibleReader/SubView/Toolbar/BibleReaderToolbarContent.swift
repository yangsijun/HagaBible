//
//  BibleReaderToolbarContent.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleReaderToolbarContent: ToolbarContent {
    let bibleBook: BibleBook?
    let chapterNum: Int
    let bibleVersion: BibleVersion?
    @Binding var showBibleNavigation: Bool
    @Binding var showFontThemeConfig: Bool
    let onListenTapped: () -> Void
    let ttsPlaybackState: TTSPlaybackState

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            BibleReaderToolbarTitleButton(
                bibleBook: bibleBook,
                chapterNum: chapterNum,
                bibleVersion: bibleVersion,
                showBibleNavigation: $showBibleNavigation
            )
        }
        ToolbarItem {
            BibleReaderToolbarIconButton(action: onListenTapped) {
                Label("Listen", systemImage: ttsPlaybackState == .playing ? "pause.fill" : "headphones")
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
                    bibleBook: .init(bookCode: "GRN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
                    chapterNum: 1,
                    bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", language: "Korean", isDownloaded: true),
                    showBibleNavigation: .constant(false),
                    showFontThemeConfig: .constant(false),
                    onListenTapped: {},
                    ttsPlaybackState: .idle
                )
            }
    }
}
