//
//  PagedBibleReaderView.swift
//  HagaBible
//

import SwiftUI

/// SwiftUI face of the book-style ("page turning") reader. Replaces the scrolling verse
/// list when the Labs toggle is on; see `PagedReaderController` for the behaviour.
struct PagedBibleReaderView: UIViewControllerRepresentable {
    let content: ChapterContent
    /// The safe area the text must stay inside; the view itself runs under the bars so
    /// the page curl covers the whole screen.
    let contentInsets: EdgeInsets
    let style: PageTextStyle
    /// Two pages side by side in landscape (Labs toggle, on by default).
    let isSpreadEnabled: Bool
    let highlightedVerseNum: Int?
    let ttsVerseIndex: Int?
    /// Selected verse numbers (1-based), mirrored from the reader's selection indices.
    let selectedVerses: ClosedRange<Int>?
    let bookmarkStripes: [Int: [BookmarkStripe?]]
    /// Flips on every explicit navigation; the reader then turns to `targetVerse`.
    let navigationToken: Bool
    let targetVerse: Int
    let fetchNeighbor: (ChapterKey, _ forward: Bool) async -> ChapterContent?
    let onPageChanged: (ChapterKey, _ firstVerse: Int) -> Void
    let onUserInteraction: () -> Void
    /// A tap on a verse (verse number) of the displayed chapter.
    let onVerseTapped: (Int) -> Void
    /// Long-press menu for a verse (verse number) of the displayed chapter.
    let contextMenu: (Int) -> UIMenu?
    /// Window x where the verse column starts; the toolbar title lines up with it.
    let onTextLeadingChanged: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> PagedReaderController {
        PagedReaderController()
    }

    func updateUIViewController(_ controller: PagedReaderController, context: Context) {
        controller.contentInsets = UIEdgeInsets(
            top: contentInsets.top, left: contentInsets.leading, bottom: contentInsets.bottom, right: contentInsets.trailing
        )
        controller.isSpreadEnabled = isSpreadEnabled
        controller.fetchNeighbor = fetchNeighbor
        controller.onPageChanged = onPageChanged
        controller.onUserInteraction = onUserInteraction
        controller.onVerseTapped = onVerseTapped
        controller.contextMenu = contextMenu
        controller.onTextLeadingChanged = onTextLeadingChanged
        controller.apply(
            content: content,
            style: style,
            highlights: .init(navigatedVerse: highlightedVerseNum, ttsVerseIndex: ttsVerseIndex, selectedVerses: selectedVerses),
            bookmarkStripes: bookmarkStripes,
            navigationToken: navigationToken,
            targetVerse: targetVerse
        )
    }
}

extension PageTextStyle {
    /// Resolves the reader's font configuration and theme into concrete fonts and colors,
    /// matching what `BibleVerseListView` renders (comparison text at 0.82× the body size).
    static func make(
        fontConfiguration: FontConfiguration,
        theme: Theme,
        language: String,
        compareLanguage: String
    ) -> PageTextStyle {
        let size = CGFloat(fontConfiguration.size)
        let font = getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: size)
        let compareBase = getUIFontFromFontConfiguration(fontConfiguration, language: compareLanguage) ?? .systemFont(ofSize: size)
        return PageTextStyle(
            font: font,
            compareFont: compareBase.withSize(compareBase.pointSize * 0.82),
            textColor: theme.textColor,
            verseNumberColor: theme.verseNumberColor,
            backgroundColor: theme.backgroundColor,
            alignment: fontConfiguration.alignment[language]?.nsAlignment ?? .natural,
            compareAlignment: fontConfiguration.alignment[compareLanguage]?.nsAlignment ?? .natural,
            lineSpacing: CGFloat(fontConfiguration.lineSpacing),
            sideMargin: CGFloat(fontConfiguration.sideMargin)
        )
    }
}
