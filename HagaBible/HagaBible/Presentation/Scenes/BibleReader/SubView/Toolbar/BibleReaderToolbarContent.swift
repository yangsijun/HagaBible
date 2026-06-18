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
    let isTTSEnabled: Bool
    let onLabsTapped: () -> Void
    let onReminderTapped: () -> Void
    let onBookmarksTapped: () -> Void
    let onReadingChecklistTapped: () -> Void
    let comparableVersions: [BibleVersion]
    let compareVersionCode: String?
    let onSelectCompareVersion: (String?) -> Void

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
            BibleReaderToolbarMenuButton {
                if isTTSEnabled {
                    Button(action: onListenTapped) {
                        Label(
                            ttsPlaybackState == .idle ? "Listen" : "Stop Listening",
                            systemImage: ttsPlaybackState == .idle ? "headphones" : "headphones.slash"
                        )
                    }
                }
                Menu {
                    BibleReaderCompareMenuItems(
                        versions: comparableVersions,
                        selectedVersionCode: compareVersionCode,
                        onSelect: onSelectCompareVersion
                    )
                } label: {
                    Label(
                        "Compare",
                        systemImage: compareVersionCode == nil ? "rectangle.split.1x2" : "rectangle.split.1x2.fill"
                    )
                }
                Divider()
                Button(action: onBookmarksTapped) {
                    Label("Bookmarks", systemImage: "bookmark")
                }
                Button(action: onReadingChecklistTapped) {
                    Label("Reading Checklist", systemImage: "checklist")
                }
                Divider()
                Button {
                    showFontThemeConfig.toggle()
                } label: {
                    Label("Font & Themes", systemImage: "textformat.size")
                }
                Button(action: onReminderTapped) {
                    Label("Reading Reminder", systemImage: "bell")
                }
                Button(action: onLabsTapped) {
                    Label("Labs", systemImage: "testtube.2")
                }
            } label: {
                Label("Other", systemImage: "ellipsis")
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
                    bibleBook: .init(bookCode: "GRN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
                    chapterNum: 1,
                    bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
                    showBibleNavigation: .constant(false),
                    showFontThemeConfig: .constant(false),
                    onListenTapped: {},
                    ttsPlaybackState: .idle,
                    isTTSEnabled: true,
                    onLabsTapped: {},
                    onReminderTapped: {},
                    onBookmarksTapped: {},
                    onReadingChecklistTapped: {},
                    comparableVersions: [
                        .init(versionCode: "WEBBE", versionName: "World English Bible", versionShortName: "WEBBE", language: "English", isDownloaded: true)
                    ],
                    compareVersionCode: nil,
                    onSelectCompareVersion: { _ in }
                )
            }
    }
}
