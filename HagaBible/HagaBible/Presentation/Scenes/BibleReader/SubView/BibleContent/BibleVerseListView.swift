//
//  BibleVerseListView.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleVerseListView: View {
    let verses: [BibleVerse]
    let language: String
    var fontConfiguration: FontConfiguration
    var theme: Theme
    var highlightedVerseNum: Int?
    var ttsCurrentVerseIndex: Int?
    var bookmarkStripesPerVerse: [Int: [BookmarkStripe?]] = [:]
    /// Comparison-translation text keyed by verse number; empty when off (역본 대조).
    var compareTextByVerse: [Int: String] = [:]
    /// Language of the comparison version, used to pick its font family/alignment.
    var compareLanguage: String = "English"
    /// When true, copy/share emit a version-choice request to the parent instead
    /// of acting directly (역본 선택 dialog).
    var isComparisonOn: Bool = false
    var onCompareCopy: (_ startIndex: Int, _ endIndex: Int) -> Void = { _, _ in }
    var onCompareShare: (_ startIndex: Int, _ endIndex: Int) -> Void = { _, _ in }
    var onAddBookmark: (_ startIndex: Int, _ endIndex: Int) -> Void = { _, _ in }

    var bibleActionService: BibleActionService = DIContainer.shared.resolve(type: BibleActionService.self)

    @Binding var selectStartIndex: Int?
    @Binding var selectEndIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(0)
            LazyVStack(spacing: 0) {
                ForEach(0..<verses.count, id: \.self) { index in
                    verseRow(at: index)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private static let verseRowInnerPadding: CGFloat = 8
    /// Leading inset that aligns comparison text under the main verse text column,
    /// derived from `BibleVerseView`'s own verse-number column metrics (which scale
    /// with the reader's font size).
    private var compareLeadingInset: CGFloat {
        BibleVerseView.verseNumberColumnWidth(forBodyFontSize: CGFloat(fontConfiguration.size))
            + BibleVerseView.verseNumberSpacing
    }
    /// Comparison font size relative to the main font.
    private static let compareFontScale: CGFloat = 0.82

    @ViewBuilder
    private func verseRow(at index: Int) -> some View {
        let stripes = bookmarkStripesPerVerse[index + 1] ?? []
        let spacing = CGFloat(fontConfiguration.lineSpacing)
        let isLast = index == verses.count - 1
        let bottomGap: CGFloat = isLast ? 0 : spacing
        verseContent(at: index)
            .id(index + 1)
            .padding(Self.verseRowInnerPadding)
            .padding(.horizontal, Self.verseRowInnerPadding)
            .background(highlightedVerseNum == index + 1 ? Color.orange.opacity(0.25) : .clear)
            .background(ttsCurrentVerseIndex == index ? Color.green.opacity(0.2) : .clear)
            .background(isSelected(index) ? Color.accentColor.opacity(0.25) : .clear)
            .contentShape(.rect)
            .contextMenu {
                Button(action: {
                    let (start, end) = getSelectIndexFromContextMenuIndex(index)
                    onAddBookmark(start, end)
                }) {
                    Label("Add bookmark", systemImage: "bookmark")
                }
                Button(action: {
                    if isComparisonOn {
                        let (start, end) = getSelectIndexFromContextMenuIndex(index)
                        onCompareCopy(start, end)
                    } else {
                        UIPasteboard.general.string = getVerseTextsFromContextMenuIndex(index)
                        selectStartIndex = nil
                        selectEndIndex = nil
                    }
                }) {
                    Label("Copy to clipboard", systemImage: "doc.on.doc")
                }
                if isComparisonOn {
                    Button(action: {
                        let (start, end) = getSelectIndexFromContextMenuIndex(index)
                        onCompareShare(start, end)
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(
                        item: getVerseTextsFromContextMenuIndex(index)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            } preview: {
                contextMenuPreview(for: index)
            }
            .onTapGesture {
                handleSelectVerse(index)
            }
            .padding(.bottom, bottomGap)
            .overlay(alignment: .leading) {
                if !stripes.isEmpty {
                    HStack(spacing: 1) {
                        ForEach(Array(stripes.prefix(BookmarkStripeComputer.columnLimit).enumerated()), id: \.offset) { _, stripe in
                            stripeView(stripe, bottomGap: bottomGap)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func stripeView(_ stripe: BookmarkStripe?, bottomGap: CGFloat) -> some View {
        if let stripe = stripe {
            let topInset: CGFloat = stripe.extendsUp ? 0 : Self.verseRowInnerPadding
            let bottomInset: CGFloat = stripe.extendsDown ? 0 : (Self.verseRowInnerPadding + bottomGap)
            Rectangle()
                .fill(stripe.color.swiftUIColor)
                .opacity(0.8)
                .frame(width: 3)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
        } else {
            Color.clear
                .frame(width: 3)
        }
    }

    /// The main verse stacked over its comparison verse (when comparison is on).
    @ViewBuilder
    private func verseContent(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            makeVerseView(at: index)
            if let compareText = compareTextByVerse[index + 1], !compareText.isEmpty {
                makeCompareView(text: compareText)
                    .padding(.leading, compareLeadingInset)
            }
        }
    }

    private func makeCompareView(text: String) -> BibleCompareVerseView {
        BibleCompareVerseView(
            verseText: text,
            font: compareUIFont(),
            textColor: theme.textColor.withAlphaComponent(0.5),
            alignment: fontConfiguration.alignment[compareLanguage]?.nsAlignment ?? .natural,
            lineSpacing: CGFloat(fontConfiguration.lineSpacing)
        )
    }

    private func compareUIFont() -> UIFont {
        let base = getUIFontFromFontConfiguration(fontConfiguration, language: compareLanguage)
            ?? .systemFont(ofSize: CGFloat(fontConfiguration.size))
        return base.withSize(base.pointSize * Self.compareFontScale)
    }

    private func makeVerseView(at index: Int) -> BibleVerseView {
        let verseNumber = index + 1
        return BibleVerseView(
            verseNumber: verseNumber,
            verseText: verses[index].verseText ?? "",
            font: getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: CGFloat(fontConfiguration.size)),
            textColor: theme.textColor,
            verseNumberColor: theme.verseNumberColor,
            alignment: fontConfiguration.alignment[language]?.nsAlignment ?? .natural,
            lineSpacing: CGFloat(fontConfiguration.lineSpacing)
        )
    }

    private func isSelected(_ index: Int) -> Bool {
        guard let start = selectStartIndex, let end = selectEndIndex else { return false }
        return index >= start && index <= end
    }

    @ViewBuilder
    private func contextMenuPreview(for index: Int) -> some View {
        if let start = selectStartIndex, let end = selectEndIndex, start <= index && index <= end {
            NavigationStack {
                VStack(spacing: 0) {
                    ForEach(start...end, id: \.self) { idx in
                        makeVerseView(at: idx)
                            .padding(8)
                            .padding(.horizontal, 8)
                            .background(Color.accentColor.opacity(0.25))
                    }
                }
            }
        } else {
            NavigationStack {
                makeVerseView(at: index)
                    .padding(8)
                    .padding(.horizontal, 8)
                    .background(Color.accentColor.opacity(0.25))
            }
        }
    }
    
    private func getVerseTextsFromContextMenuIndex(_ index: Int) -> String {
        let (start, end) = getSelectIndexFromContextMenuIndex(index)
        return bibleActionService.makeVerseStringFromVerseList(verses, start: start, end: end)
    }
    
    private func getSelectIndexFromContextMenuIndex(_ index: Int) -> (Int, Int) {
        if let selectStartIndex = selectStartIndex, let selectEndIndex = selectEndIndex {
            if index >= selectStartIndex && index <= selectEndIndex {
                return (selectStartIndex, selectEndIndex)
            }
        }
        return (index, index)
    }
    
    private func handleSelectVerse(_ index: Int) {
        guard selectStartIndex != nil, selectEndIndex != nil else {
            selectStartIndex = index
            selectEndIndex = index
            return
        }
        if index < selectStartIndex! {
            selectStartIndex = index
            return
        }
        if index == selectStartIndex! {
            if index == selectEndIndex! {
                selectStartIndex = nil
                selectEndIndex = nil
            } else {
                selectStartIndex! += 1
            }
            return
        }
        if index > selectStartIndex! {
            if index <= selectEndIndex! {
                selectEndIndex = index - 1
            } else {
                selectEndIndex = index
            }
        }
    }
}

#Preview {
    let verses: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    
     BibleVerseListView(
        verses: verses,
        language: "Korean",
        fontConfiguration: FontConfiguration(
            type: [
                "English": .sans,
                "Korean": .serif,
            ],
            style: .regular,
            size: 17,
            alignment: [
                "English": .natural,
                "Korean": .justified
            ]
        ),
        theme: Theme.system,
        highlightedVerseNum: 1,
        ttsCurrentVerseIndex: nil,
        selectStartIndex: .constant(2),
        selectEndIndex: .constant(2)
    )
}

#Preview("Bookmark stripes") {
    DIContainer.registerForPreview()

    let verses: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 4, verseText: "그 빛이 하나님의 보시기에 좋았더라 하나님이 빛과 어두움을 나누사", versionCode: "KRV"),
    ]

    // Yellow spans v1-2 in column 0; pink reuses column 0 at v3 once yellow ends.
    // Blue is a single at v2; green spans v2-4. Stripe layout is derived by the
    // real algorithm so the preview stays in sync with production behavior.
    let bookmarks: [Bookmark] = [
        .previewSample(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 1, endVerse: 2, color: .yellow),
        .previewSample(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 2, color: .blue),
        .previewSample(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 2, endVerse: 4, color: .green),
        .previewSample(bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 3, color: .pink),
    ]
    let stripesPerVerse = BookmarkStripeComputer.computeStripes(from: bookmarks)

    return BibleVerseListView(
        verses: verses,
        language: "Korean",
        fontConfiguration: FontConfiguration(
            type: [
                "English": .sans,
                "Korean": .serif,
            ],
            style: .regular,
            size: 17,
            alignment: [
                "English": .natural,
                "Korean": .justified
            ],
            lineSpacing: 8
        ),
        theme: Theme.system,
        highlightedVerseNum: nil,
        ttsCurrentVerseIndex: nil,
        bookmarkStripesPerVerse: stripesPerVerse,
        selectStartIndex: .constant(nil),
        selectEndIndex: .constant(nil)
    )
}
