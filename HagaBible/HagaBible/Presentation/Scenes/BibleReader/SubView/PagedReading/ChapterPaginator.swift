//
//  ChapterPaginator.swift
//  HagaBible
//

import UIKit

/// One chapter of one version — the unit the paged reader lays out and prefetches.
struct ChapterKey: Hashable, Sendable {
    let versionCode: String
    let bookCode: String
    let chapter: Int
}

/// Everything the paged reader needs to typeset a chapter. No heading: the toolbar
/// title already names the chapter.
struct ChapterContent: Equatable, Sendable {
    let key: ChapterKey
    let verses: [BibleVerse]
    /// Comparison-translation text keyed by verse number; empty when comparison is off.
    let compareTextByVerse: [Int: String]
}

/// Fonts and colors the paged reader typesets with, resolved from the reader's font
/// configuration and theme (see `PageTextStyle.make` in `PagedBibleReaderView`).
struct PageTextStyle: Equatable {
    var font: UIFont
    var compareFont: UIFont
    var textColor: UIColor
    var verseNumberColor: UIColor
    /// Page paper color. Pages must be opaque: a curling leaf is drawn over the page
    /// beneath it, so a transparent page would show both texts at once.
    var backgroundColor: UIColor
    var alignment: NSTextAlignment
    var compareAlignment: NSTextAlignment
    var lineSpacing: CGFloat
    /// Extra side margin (the Font & Theme setting) added to each page's built-in margins.
    var sideMargin: CGFloat = 0

    /// Colors compare by resolved value: the theme hands out a fresh `UIColor` object on
    /// every access, and treating each as a change would re-typeset (and replace the
    /// pages) on every SwiftUI update, including mid-flip.
    private static func sameColor(_ lhs: UIColor, _ rhs: UIColor) -> Bool {
        lhs == rhs || lhs.cgColor == rhs.cgColor
    }

    static func == (lhs: PageTextStyle, rhs: PageTextStyle) -> Bool {
        lhs.font == rhs.font
            && lhs.compareFont == rhs.compareFont
            && sameColor(lhs.textColor, rhs.textColor)
            && sameColor(lhs.verseNumberColor, rhs.verseNumberColor)
            && sameColor(lhs.backgroundColor, rhs.backgroundColor)
            && lhs.alignment == rhs.alignment
            && lhs.compareAlignment == rhs.compareAlignment
            && lhs.lineSpacing == rhs.lineSpacing
            && lhs.sideMargin == rhs.sideMargin
    }
}

/// Lays a chapter out into fixed-size pages the way a book is typeset: one text storage,
/// one layout manager, and one `NSTextContainer` per page, so a long verse flows across
/// a page break mid-sentence instead of being clipped or pushed whole to the next page.
///
/// Verse numbers are set inline as a hanging indent (number, tab, text) that mirrors the
/// scroll reader's number column: the column is as wide as the chapter's widest number
/// (at least `BibleVerseView`'s base column), scaled with the body font.
///
/// **Parallel mode** (`parallel: true` with comparison text): facing pages carry the main
/// text on the left and the comparison text on the right, verse rows aligned like a
/// parallel Bible. Verses are never split across a spread (a verse taller than a page is
/// clipped), each page has its own storage and layout manager, and page `2k` is the left
/// page of spread `k`, `2k + 1` its right page.
///
/// TextKit 1 is used deliberately: multi-container pagination is a TextKit 1 feature.
@MainActor
final class ChapterPaginator {
    /// One typeset page: what to draw and where each verse sits in that storage.
    private struct Page {
        let storage: NSTextStorage
        let layoutManager: NSLayoutManager
        let container: NSTextContainer
        /// Character range (in `storage`) laid out on this page.
        let range: NSRange
        /// Character range of each verse block in `storage`, by verse number.
        let verseRanges: [Int: NSRange]
    }

    /// Layout manager of the flowing layout (every page in the default mode). In parallel
    /// mode each page has its own; use `layoutManager(forPage:)` to draw.
    let layoutManager = NSLayoutManager()
    let textStorage: NSTextStorage
    /// Size each page's text area was laid out for.
    let pageSize: CGSize
    /// Vertical gap between verse blocks (the scroll reader's 8+8pt row padding plus the
    /// configured line spacing). Exposed so bookmark stripes can bridge adjacent verses.
    let verseGap: CGFloat
    /// Facing pages show the main text (left) and the comparison text (right), rows aligned.
    let isParallel: Bool

    private var pages: [Page] = []
    /// Verse numbers in reading order.
    private let verseOrder: [Int]

    /// Hard cap so a degenerate page size can never spin forever.
    private static let maxPages = 2000

    var pageCount: Int { pages.count }
    /// Character range laid out on each page (flow mode: ranges in `textStorage`).
    var pageRanges: [NSRange] { pages.map(\.range) }

    /// - Parameter parallel: lay the comparison text out on facing pages (see the type
    ///   comment) instead of under each verse; ignored without comparison text.
    /// - Parameter exclusionRects: areas (in page text coordinates) text must flow
    ///   around on the given page, such as a floating tab bar that covers a corner of
    ///   right-hand pages only. Not applied in parallel mode, where both pages of a
    ///   spread must break identically.
    init(
        content: ChapterContent, style: PageTextStyle, pageSize: CGSize, parallel: Bool = false,
        exclusionRects: (_ pageIndex: Int) -> [CGRect] = { _ in [] }
    ) {
        let metrics = Metrics(content: content, style: style)
        let hasComparison = content.verses.contains { !(content.compareTextByVerse[$0.verse] ?? "").isEmpty }
        self.pageSize = CGSize(width: max(pageSize.width, 1), height: max(pageSize.height, 1))
        self.verseGap = metrics.verseGap
        self.verseOrder = content.verses.map(\.verse)
        self.isParallel = parallel && hasComparison
        if isParallel {
            self.textStorage = NSTextStorage()
            textStorage.addLayoutManager(layoutManager)
            pages = Self.buildParallelPages(content: content, style: style, metrics: metrics, pageSize: self.pageSize)
        } else {
            let built = Self.buildText(content: content, style: style, metrics: metrics)
            self.textStorage = NSTextStorage(attributedString: built.text)
            textStorage.addLayoutManager(layoutManager)
            paginateFlow(verseRanges: built.verseRanges, exclusionRects: exclusionRects)
        }
    }

    func container(at pageIndex: Int) -> NSTextContainer? {
        pages.indices.contains(pageIndex) ? pages[pageIndex].container : nil
    }

    /// The layout manager that draws the page at `pageIndex`.
    func layoutManager(forPage pageIndex: Int) -> NSLayoutManager? {
        pages.indices.contains(pageIndex) ? pages[pageIndex].layoutManager : nil
    }

    /// Page on which the verse's block begins (the left page in parallel mode); `nil` for
    /// a verse not in this chapter.
    func pageIndex(containingVerse verse: Int) -> Int? {
        guard verseOrder.contains(verse) else { return nil }
        return pages.firstIndex { page in
            guard let range = page.verseRanges[verse] else { return false }
            return NSLocationInRange(range.location, page.range)
        } ?? pages.indices.last
    }

    /// Verses with any text on the page, in order (a verse continued from the previous
    /// page counts).
    func verses(onPage pageIndex: Int) -> [Int] {
        guard pages.indices.contains(pageIndex) else { return [] }
        let page = pages[pageIndex]
        return verseOrder.filter { verse in
            guard let range = page.verseRanges[verse] else { return false }
            return NSMaxRange(range) > page.range.location && range.location < NSMaxRange(page.range)
        }
    }

    /// First verse with any text on the page, or `nil` for an empty page.
    func firstVerse(onPage pageIndex: Int) -> Int? {
        verses(onPage: pageIndex).first
    }

    /// The verse whose text lies under `point` (page text coordinates), or `nil` when the
    /// point is in a margin or below the last line — a tap there must not select.
    func verse(at point: CGPoint, onPage pageIndex: Int) -> Int? {
        guard pages.indices.contains(pageIndex) else { return nil }
        let page = pages[pageIndex]
        let layoutManager = page.layoutManager
        let pageGlyphs = layoutManager.glyphRange(for: page.container)
        guard pageGlyphs.length > 0 else { return nil }
        let glyph = layoutManager.glyphIndex(for: point, in: page.container)
        guard NSLocationInRange(glyph, pageGlyphs) else { return nil }
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        guard point.y >= line.minY, point.y <= line.maxY else { return nil }
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        return verseOrder.first { verse in
            guard let range = page.verseRanges[verse] else { return false }
            return NSLocationInRange(character, range)
        }
    }

    /// Bounding rect (page text coordinates) of the part of the verse that is on the page.
    func rect(forVerse verse: Int, onPage pageIndex: Int) -> CGRect? {
        guard pages.indices.contains(pageIndex) else { return nil }
        let page = pages[pageIndex]
        guard let range = page.verseRanges[verse] else { return nil }
        let visible = NSIntersectionRange(range, page.range)
        guard visible.length > 0 else { return nil }
        let glyphs = page.layoutManager.glyphRange(forCharacterRange: visible, actualCharacterRange: nil)
        return page.layoutManager.boundingRect(forGlyphRange: glyphs, in: page.container)
    }

    // MARK: - Flow layout

    private func paginateFlow(verseRanges: [Int: NSRange], exclusionRects: (Int) -> [CGRect]) {
        let totalGlyphs = layoutManager.numberOfGlyphs
        var laidOut = 0
        repeat {
            let container = NSTextContainer(size: pageSize)
            container.lineFragmentPadding = 0
            container.exclusionPaths = exclusionRects(pages.count).map { UIBezierPath(rect: $0) }
            layoutManager.addTextContainer(container)
            let glyphRange = layoutManager.glyphRange(for: container)
            let range = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            pages.append(Page(storage: textStorage, layoutManager: layoutManager, container: container, range: range, verseRanges: verseRanges))
            // A page too small for a single line would never make progress; stop here
            // rather than loop (the remaining text is simply not shown).
            if glyphRange.length == 0, laidOut < totalGlyphs { break }
            laidOut = NSMaxRange(glyphRange)
        } while laidOut < totalGlyphs && pages.count < Self.maxPages
    }

    // MARK: - Text

    /// Verse-number column metrics; they track the body font exactly like `BibleVerseView`.
    private struct Metrics {
        let numberAttributes: [NSAttributedString.Key: Any]
        let numberWidth: CGFloat
        let textIndent: CGFloat
        let verseGap: CGFloat

        init(content: ChapterContent, style: PageTextStyle) {
            let scale = style.font.pointSize / BibleVerseView.baseBodyFontSize
            numberAttributes = [
                .font: UIFont.systemFont(ofSize: 12 * scale),
                .foregroundColor: style.verseNumberColor,
            ]
            let widestNumber = "\(content.verses.map(\.verse).max() ?? 1)" as NSString
            numberWidth = max(
                BibleVerseView.verseNumberColumnWidth(forBodyFontSize: style.font.pointSize),
                widestNumber.size(withAttributes: numberAttributes).width
            )
            textIndent = ceil(numberWidth + BibleVerseView.verseNumberSpacing)
            verseGap = 16 + style.lineSpacing
        }

        /// Hanging-indent paragraph: the number centred in its column, the text after it.
        func paragraph(alignment: NSTextAlignment, lineSpacing: CGFloat, spacingAfter: CGFloat) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineSpacing = lineSpacing
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = textIndent
            paragraph.tabStops = [
                NSTextTab(textAlignment: .center, location: numberWidth / 2),
                NSTextTab(textAlignment: .left, location: textIndent),
            ]
            paragraph.defaultTabInterval = textIndent
            paragraph.paragraphSpacing = spacingAfter
            return paragraph
        }

        /// One verse paragraph: number, tab, text. No trailing newline after a storage's
        /// final paragraph: it would lay out an empty line that can spill onto a blank page.
        func block(
            verse: Int, text: String, font: UIFont, color: UIColor, alignment: NSTextAlignment, lineSpacing: CGFloat,
            spacingAfter: CGFloat, terminated: Bool
        ) -> NSAttributedString {
            let paragraph = paragraph(alignment: alignment, lineSpacing: lineSpacing, spacingAfter: spacingAfter)
            var number = numberAttributes
            number[.paragraphStyle] = paragraph
            let result = NSMutableAttributedString(string: "\t\(verse)\t", attributes: number)
            result.append(NSAttributedString(
                string: text + (terminated ? "\n" : ""),
                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            ))
            return result
        }
    }

    private static func buildText(
        content: ChapterContent, style: PageTextStyle, metrics: Metrics
    ) -> (text: NSAttributedString, verseRanges: [Int: NSRange]) {
        let result = NSMutableAttributedString()
        var verseRanges: [Int: NSRange] = [:]

        for (index, verse) in content.verses.enumerated() {
            let isLast = index == content.verses.count - 1
            let compareText = content.compareTextByVerse[verse.verse].flatMap { $0.isEmpty ? nil : $0 }
            let blockStart = result.length

            result.append(metrics.block(
                verse: verse.verse, text: verse.verseText ?? "", font: style.font, color: style.textColor,
                alignment: style.alignment, lineSpacing: style.lineSpacing,
                spacingAfter: compareText != nil ? 6 : (isLast ? 0 : metrics.verseGap),
                terminated: !(isLast && compareText == nil)
            ))

            if let compareText {
                let compareParagraph = NSMutableParagraphStyle()
                compareParagraph.alignment = style.compareAlignment
                compareParagraph.lineSpacing = style.lineSpacing
                compareParagraph.firstLineHeadIndent = metrics.textIndent
                compareParagraph.headIndent = metrics.textIndent
                compareParagraph.paragraphSpacing = isLast ? 0 : metrics.verseGap
                result.append(NSAttributedString(
                    string: compareText + (isLast ? "" : "\n"),
                    attributes: [
                        .font: style.compareFont,
                        .foregroundColor: style.textColor.withAlphaComponent(0.5),
                        .paragraphStyle: compareParagraph,
                    ]
                ))
            }

            verseRanges[verse.verse] = NSRange(location: blockStart, length: result.length - blockStart)
        }

        return (result, verseRanges)
    }

    // MARK: - Parallel layout

    /// Builds the facing pages: measures every verse on both sides at the page width,
    /// fills spreads with whole verses by the taller side, then typesets each page with
    /// the shorter verse padded (paragraph spacing) to the row height so rows line up.
    private static func buildParallelPages(
        content: ChapterContent, style: PageTextStyle, metrics: Metrics, pageSize: CGSize
    ) -> [Page] {
        // On its own page the comparison reads as a full peer: the main text size and
        // color, in the comparison language's font and alignment.
        let compareFont = style.compareFont.withSize(style.font.pointSize)
        let order = content.verses.map(\.verse)
        func block(_ verse: Int, side: Int, spacingAfter: CGFloat, terminated: Bool) -> NSAttributedString {
            let text = side == 0
                ? (content.verses.first { $0.verse == verse }?.verseText ?? "")
                : (content.compareTextByVerse[verse] ?? "")
            return metrics.block(
                verse: verse, text: text, font: side == 0 ? style.font : compareFont, color: style.textColor,
                alignment: side == 0 ? style.alignment : style.compareAlignment, lineSpacing: style.lineSpacing,
                spacingAfter: spacingAfter, terminated: terminated
            )
        }

        let heights = (0..<2).map { side in
            measureHeights(order: order, width: pageSize.width) { block($0, side: side, spacingAfter: 0, terminated: true) }
        }
        let rows = Dictionary(uniqueKeysWithValues: order.map { ($0, max(heights[0][$0] ?? 0, heights[1][$0] ?? 0)) })

        var spreads: [[Int]] = []
        var used: CGFloat = 0
        for verse in order {
            let row = rows[verse] ?? 0
            if spreads.last?.isEmpty == false, used + metrics.verseGap + row > pageSize.height {
                spreads.append([verse])
                used = row
            } else if spreads.isEmpty {
                spreads = [[verse]]
                used = row
            } else {
                spreads[spreads.count - 1].append(verse)
                used += metrics.verseGap + row
            }
        }

        var pages: [Page] = []
        for verses in spreads.prefix(maxPages / 2) {
            for side in 0..<2 {
                let storage = NSTextStorage()
                var verseRanges: [Int: NSRange] = [:]
                for (index, verse) in verses.enumerated() {
                    let isLast = index == verses.count - 1
                    let padding = (rows[verse] ?? 0) - (heights[side][verse] ?? 0)
                    let start = storage.length
                    storage.append(block(verse, side: side, spacingAfter: isLast ? 0 : padding + metrics.verseGap, terminated: !isLast))
                    verseRanges[verse] = NSRange(location: start, length: storage.length - start)
                }
                let layoutManager = NSLayoutManager()
                let container = NSTextContainer(size: pageSize)
                container.lineFragmentPadding = 0
                storage.addLayoutManager(layoutManager)
                layoutManager.addTextContainer(container)
                pages.append(Page(
                    storage: storage, layoutManager: layoutManager, container: container,
                    range: NSRange(location: 0, length: storage.length), verseRanges: verseRanges
                ))
            }
        }
        return pages
    }

    /// Natural height of each verse block (its line fragments, line spacing included) when
    /// typeset at `width` with no paragraph spacing, measured in one tall container with
    /// the same typesetter that will lay the pages out.
    private static func measureHeights(order: [Int], width: CGFloat, block: (Int) -> NSAttributedString) -> [Int: CGFloat] {
        let storage = NSTextStorage()
        var ranges: [Int: NSRange] = [:]
        for verse in order {
            let start = storage.length
            storage.append(block(verse))
            ranges[verse] = NSRange(location: start, length: storage.length - start)
        }
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: 10_000_000))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)

        var heights: [Int: CGFloat] = [:]
        for (verse, range) in ranges {
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var union: CGRect?
            layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                union = union.map { $0.union(rect) } ?? rect
            }
            heights[verse] = union?.height ?? 0
        }
        return heights
    }
}
