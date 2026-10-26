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
    /// Reports the laid-out height of the row at `index` (the same frame `.id` targets,
    /// padding and highlight included) whenever it changes; the reader uses it to place
    /// the spoken verse's top edge on a fixed line during TTS auto-follow.
    var onRowHeightChange: (_ index: Int, _ height: CGFloat) -> Void = { _, _ in }

    var bibleActionService: BibleActionService = DIContainer.shared.resolve(type: BibleActionService.self)

    @Binding var selectStartIndex: Int?
    @Binding var selectEndIndex: Int?

    /// Measured list width, fed to the context-menu preview: the preview is laid
    /// out in a detached window where `AdvancedText` gets no width proposal (and
    /// would size to a single infinite line), so it needs a definite width.
    @State private var listWidth: CGFloat = 0
    @State private var listHeight: CGFloat = 0

    var body: some View {
        // Scroll-target ids are 1-based verse ordinals and `0` is this zero-height
        // spacer marking the true top of the list. The ForEach iterates the same
        // ordinals so its identity and the explicit `.id(index + 1)` on each row agree:
        // iOS 26 resolves `ScrollViewProxy.scrollTo` through the explicit id, but iOS 27
        // resolves it through the ForEach identity, and with a 0-based ForEach that
        // landed every scroll one verse off (verified on the 26.5 and 27.0 simulators).
        // Callers pass verse ordinals: `scrollTo(n - 1)` deliberately parks the verse
        // *before* n at the top (one line of context above n), `scrollTo(0)` goes to
        // the top, and `scrollTo(n)` targets verse n itself.
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(0)
            LazyVStack(spacing: 0) {
                ForEach(1..<verses.count + 1, id: \.self) { ordinal in
                    verseRow(at: ordinal - 1)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, CGFloat(fontConfiguration.sideMargin))
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            listWidth = size.width
            listHeight = size.height
        }
    }

    /// Widest the long-press preview gets. A landscape phone, an iPad or an unfolded
    /// foldable is far wider than the preview area the context menu grants (the menu
    /// sits beside the preview there), and an over-wide preview is container-shrunk by
    /// the system and clipped; a reading-column width always fits.
    private static let previewMaxWidth: CGFloat = 420

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
            .padding(Self.verseRowInnerPadding)
            .padding(.horizontal, Self.verseRowInnerPadding)
            .background(highlightedVerseNum == index + 1 ? Color.orange.opacity(0.25) : .clear)
            .background(ttsCurrentVerseIndex == index ? Color.green.opacity(0.2) : .clear)
            .background(isSelected(index) ? Color.accentColor.opacity(0.25) : .clear)
            // Row height for the TTS follow-scroll anchor. This measures exactly the frame
            // `.id(index + 1)` below scrolls to (padding + highlight, no bottom gap), so
            // the anchor math and the scroll target agree.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                onRowHeightChange(index, height)
            }
            // Scroll-target id (1-based, equal to the ForEach identity; see `body`).
            // Attached to the padded, highlighted row rather than the bare text so an
            // anchored scroll aligns the highlight band itself instead of clipping its
            // top padding.
            //
            // Keep this AFTER `.onGeometryChange`: on iOS 26 a geometry-change modifier
            // applied outside the id hides it from `ScrollViewProxy.scrollTo` (verified
            // on the 26.5 simulator). The `.contentShape`/`.contextMenu`/`.padding`/
            // `.overlay` chain that follows does not have that effect.
            .id(index + 1)
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
        // A definite width lets AdvancedText compute its wrapped height, so the
        // preview hugs its content instead of taking the system's default size.
        // When the content is taller than the space the context menu allows, the
        // system shrinks only the preview container and re-lays the SwiftUI
        // content out at full size (clipping it), so we scale the whole content
        // down ourselves to keep every selected verse visible.
        let (start, end) = getSelectIndexFromContextMenuIndex(index)
        let width = min(max(listWidth, 1), Self.previewMaxWidth)
        let contentHeight = max(estimatedPreviewHeight(start: start, end: end, width: width), 1)
        // Budget from the list's own size, not the screen: in a landscape or wide layout
        // the menu sits beside the preview, so more of the height is available.
        let isWide = listWidth > listHeight
        let maxHeight = max(listHeight, 1) * (isWide ? 0.8 : 0.55)
        let budgetScale = min(1, maxHeight / contentHeight)
        let idealSize = CGSize(width: width * budgetScale, height: contentHeight * budgetScale)
        // The budget is a guess at the area the system grants; when it grants less (it
        // did in landscape and on a foldable) the container shrinks under the content.
        // So the content scales to whatever size it actually gets instead of clipping.
        GeometryReader { proxy in
            let scale = min(proxy.size.width / width, proxy.size.height / contentHeight)
            VStack(spacing: 0) {
                ForEach(start...end, id: \.self) { idx in
                    makeVerseView(at: idx)
                        .padding(8)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor.opacity(0.25))
                }
            }
            .frame(width: width)
            .background(Color(uiColor: theme.backgroundColor))
            .scaleEffect(scale, anchor: .topLeading)
        }
        .frame(minWidth: 0, idealWidth: idealSize.width, maxWidth: idealSize.width, minHeight: 0, idealHeight: idealSize.height, maxHeight: idealSize.height)
        .aspectRatio(idealSize.width / idealSize.height, contentMode: .fit)
        .background(Color(uiColor: theme.backgroundColor))
    }

    /// Height the preview's verse stack will lay out at for a given width,
    /// mirroring `verseRow`'s paddings and `AdvancedText`'s UITextView sizing so
    /// the scaled-down preview frame matches the rendered content.
    private func estimatedPreviewHeight(start: Int, end: Int, width: CGFloat) -> CGFloat {
        guard verses.indices.contains(start), verses.indices.contains(end), start <= end else { return 1 }
        let bodyFont = getUIFontFromFontConfiguration(fontConfiguration, language: language)
            ?? .systemFont(ofSize: CGFloat(fontConfiguration.size))
        let metricScale = bodyFont.pointSize / BibleVerseView.baseBodyFontSize
        let numberFontSize = 12 * metricScale
        let numberMinHeight = 22 * metricScale
        let numberMinWidth = BibleVerseView.verseNumberColumnWidth(forBodyFontSize: bodyFont.pointSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = fontConfiguration.alignment[language]?.nsAlignment ?? .natural
        paragraphStyle.lineSpacing = CGFloat(fontConfiguration.lineSpacing)

        let scratch = UITextView()
        scratch.isScrollEnabled = false
        scratch.textContainer.lineFragmentPadding = 0
        scratch.textContainerInset = .zero

        var total: CGFloat = 0
        for idx in start...end {
            // Standard-width digits overestimate the condensed verse-number
            // column slightly, which errs toward a shorter text column — a
            // taller estimate letterboxes instead of clipping.
            let numberWidth = max(
                numberMinWidth,
                ceil(("\(idx + 1)" as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: numberFontSize)]).width)
            )
            let textWidth = width - 32 - numberWidth - BibleVerseView.verseNumberSpacing
            scratch.attributedText = NSAttributedString(
                string: verses[idx].verseText ?? "",
                attributes: [.font: bodyFont, .paragraphStyle: paragraphStyle]
            )
            let textHeight = scratch.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
            total += max(textHeight, numberMinHeight) + 16
        }
        return total
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
        (selectStartIndex, selectEndIndex) = Self.selection(afterTapping: index, start: selectStartIndex, end: selectEndIndex)
    }

    /// The tap-to-select rule, shared with the paged reader: first tap selects one verse,
    /// a tap above extends up, a tap past the end extends down, a tap inside trims the
    /// selection to end just before it (or clears it when only one verse is selected).
    static func selection(afterTapping index: Int, start: Int?, end: Int?) -> (start: Int?, end: Int?) {
        guard let start, let end else { return (index, index) }
        if index < start { return (index, end) }
        if index == start {
            return index == end ? (nil, nil) : (start + 1, end)
        }
        return index <= end ? (start, index - 1) : (start, index)
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
