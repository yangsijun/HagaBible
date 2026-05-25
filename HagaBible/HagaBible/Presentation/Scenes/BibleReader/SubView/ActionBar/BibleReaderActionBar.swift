//
//  BibleReaderActionBar.swift
//  HagaBible
//
//  Created by 양시준 on 10/12/25.
//

import SwiftUI

/// Which action-bar button the export dialog should anchor to (copy vs share),
/// so the iOS 26 confirmationDialog bubble points at the actually-tapped button.
enum VerseExportDialogMode { case copy, share }

struct BibleReaderActionBar: View {
    @Binding var selectStartIndex: Int?
    @Binding var selectEndIndex: Int?
    var bibleVerseList: [BibleVerse] = []
    var bibleActionService: BibleActionService = DIContainer.shared.resolve(type: BibleActionService.self)
    var onBookmarkTapped: () -> Void = {}
    /// When true, copy/share emit a version-choice request to the parent instead
    /// of acting directly (역본 선택 dialog).
    var isComparisonOn: Bool = false
    var onCompareCopy: (_ startIndex: Int, _ endIndex: Int) -> Void = { _, _ in }
    var onCompareShare: (_ startIndex: Int, _ endIndex: Int) -> Void = { _, _ in }
    /// Drives + anchors the version-choice dialog. The dialog is attached to the
    /// matching button so it appears as a bubble pointing at that button.
    var exportDialogMode: VerseExportDialogMode? = nil
    var exportDialogTitle: String = ""
    var exportMainVersionName: String = ""
    var exportCompareVersionName: String = ""
    var onExportScopeChosen: (_ scope: BibleReaderViewModel.VerseExportScope) -> Void = { _ in }
    var onExportCancel: () -> Void = {}

    var bibleVersesString: String {
        bibleActionService.makeVerseStringFromVerseList(bibleVerseList, start: selectStartIndex ?? 0, end: selectEndIndex ?? 0)
    }

    private var selectedRange: (start: Int, end: Int) {
        let start = selectStartIndex ?? 0
        return (start, selectEndIndex ?? start)
    }

    var body: some View {
        if selectStartIndex != nil || selectEndIndex != nil {
            ActionBar {
                ActionBarButton(action: { onBookmarkTapped() }, systemImage: "bookmark")
                ActionBarButton(action: {
                    if isComparisonOn {
                        onCompareCopy(selectedRange.start, selectedRange.end)
                    } else {
                        copyVerseTextToClipboard()
                    }
                }, systemImage: "doc.on.doc")
                .confirmationDialog(
                    exportDialogTitle,
                    isPresented: exportDialogBinding(for: .copy),
                    titleVisibility: .visible
                ) {
                    exportDialogButtons()
                }
                if isComparisonOn {
                    ActionBarButton(action: {
                        onCompareShare(selectedRange.start, selectedRange.end)
                    }, systemImage: "square.and.arrow.up")
                    .confirmationDialog(
                        exportDialogTitle,
                        isPresented: exportDialogBinding(for: .share),
                        titleVisibility: .visible
                    ) {
                        exportDialogButtons()
                    }
                } else {
                    ActionBarShareLink(item: bibleVersesString)
                }
            }
        }
    }

    private func exportDialogBinding(for mode: VerseExportDialogMode) -> Binding<Bool> {
        Binding(
            get: { exportDialogMode == mode },
            set: { if !$0 { onExportCancel() } }
        )
    }

    @ViewBuilder
    private func exportDialogButtons() -> some View {
        Button(exportMainVersionName) { onExportScopeChosen(.main) }
        Button(exportCompareVersionName) { onExportScopeChosen(.compare) }
        Button("Both") { onExportScopeChosen(.both) }
        Button("Cancel", role: .cancel) { onExportCancel() }
    }

    private func copyVerseTextToClipboard() {
        UIPasteboard.general.string = bibleVersesString

        selectStartIndex = nil
        selectEndIndex = nil
    }
}

#Preview {
    let bibleVerseList: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    BibleReaderActionBar(selectStartIndex: .constant(0), selectEndIndex: .constant(2), bibleVerseList: bibleVerseList, onBookmarkTapped: {})
}
