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
/// TextKit 1 is used deliberately: multi-container pagination is a TextKit 1 feature.
@MainActor
final class ChapterPaginator {
    let layoutManager = NSLayoutManager()
    let textStorage: NSTextStorage
    /// Size each page's text area was laid out for.
    let pageSize: CGSize
    /// Vertical gap between verse blocks (the scroll reader's 8+8pt row padding plus the
    /// configured line spacing). Exposed so bookmark stripes can bridge adjacent verses.
    let verseGap: CGFloat

    private(set) var containers: [NSTextContainer] = []
    /// Character range laid out on each page.
    private(set) var pageRanges: [NSRange] = []
    /// Character range of each verse block (number, text, and its comparison text), by verse number.
    private let verseRanges: [Int: NSRange]
    /// Verse numbers in reading order.
    private let verseOrder: [Int]

    /// Hard cap so a degenerate page size can never spin forever.
    private static let maxPages = 2000

    var pageCount: Int { containers.count }

    /// - Parameter exclusionRects: areas (in page text coordinates) text must flow
    ///   around on the given page — a fold crease running across every page, or a
    ///   floating tab bar that covers a corner of right-hand pages only.
    init(content: ChapterContent, style: PageTextStyle, pageSize: CGSize, exclusionRects: (_ pageIndex: Int) -> [CGRect] = { _ in [] }) {
        let built = Self.buildText(content: content, style: style)
        self.textStorage = NSTextStorage(attributedString: built.text)
        self.verseRanges = built.verseRanges
        self.verseOrder = built.verseOrder
        self.verseGap = built.verseGap
        self.pageSize = CGSize(width: max(pageSize.width, 1), height: max(pageSize.height, 1))
        textStorage.addLayoutManager(layoutManager)
        paginate(exclusionRects: exclusionRects)
    }

    func container(at pageIndex: Int) -> NSTextContainer? {
        containers.indices.contains(pageIndex) ? containers[pageIndex] : nil
    }

    /// Page on which the verse's block begins; `nil` for a verse not in this chapter.
    func pageIndex(containingVerse verse: Int) -> Int? {
        guard let range = verseRanges[verse] else { return nil }
        return pageRanges.firstIndex { NSLocationInRange(range.location, $0) }
            ?? pageRanges.indices.last
    }

    /// Verses with any text on the page, in order (a verse continued from the previous
    /// page counts).
    func verses(onPage pageIndex: Int) -> [Int] {
        guard pageRanges.indices.contains(pageIndex) else { return [] }
        let page = pageRanges[pageIndex]
        return verseOrder.filter { verse in
            guard let range = verseRanges[verse] else { return false }
            return NSMaxRange(range) > page.location && range.location < NSMaxRange(page)
        }
    }

    /// First verse with any text on the page, or `nil` for an empty page.
    func firstVerse(onPage pageIndex: Int) -> Int? {
        verses(onPage: pageIndex).first
    }

    /// The verse whose text lies under `point` (page text coordinates), or `nil` when the
    /// point is in a margin or below the last line — a tap there must not select.
    func verse(at point: CGPoint, onPage pageIndex: Int) -> Int? {
        guard let container = container(at: pageIndex) else { return nil }
        let pageGlyphs = layoutManager.glyphRange(for: container)
        guard pageGlyphs.length > 0 else { return nil }
        let glyph = layoutManager.glyphIndex(for: point, in: container)
        guard NSLocationInRange(glyph, pageGlyphs) else { return nil }
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        guard point.y >= line.minY, point.y <= line.maxY else { return nil }
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        return verseOrder.first { verse in
            guard let range = verseRanges[verse] else { return false }
            return NSLocationInRange(character, range)
        }
    }

    /// Bounding rect (page text coordinates) of the part of the verse that is on the page.
    func rect(forVerse verse: Int, onPage pageIndex: Int) -> CGRect? {
        guard let container = container(at: pageIndex), let range = verseRanges[verse] else { return nil }
        let pageRange = pageRanges[pageIndex]
        let visible = NSIntersectionRange(range, pageRange)
        guard visible.length > 0 else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: visible, actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
    }

    // MARK: - Layout

    private func paginate(exclusionRects: (Int) -> [CGRect]) {
        let totalGlyphs = layoutManager.numberOfGlyphs
        var laidOut = 0
        repeat {
            let container = NSTextContainer(size: pageSize)
            container.lineFragmentPadding = 0
            container.exclusionPaths = exclusionRects(containers.count).map { UIBezierPath(rect: $0) }
            layoutManager.addTextContainer(container)
            containers.append(container)
            let glyphRange = layoutManager.glyphRange(for: container)
            pageRanges.append(layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil))
            // A page too small for a single line would never make progress; stop here
            // rather than loop (the remaining text is simply not shown).
            if glyphRange.length == 0, laidOut < totalGlyphs { break }
            laidOut = NSMaxRange(glyphRange)
        } while laidOut < totalGlyphs && containers.count < Self.maxPages
    }

    private static func buildText(
        content: ChapterContent,
        style: PageTextStyle
    ) -> (text: NSAttributedString, verseRanges: [Int: NSRange], verseOrder: [Int], verseGap: CGFloat) {
        let result = NSMutableAttributedString()
        var verseRanges: [Int: NSRange] = [:]
        var verseOrder: [Int] = []

        // Verse-number metrics track the body font exactly like `BibleVerseView`.
        let scale = style.font.pointSize / BibleVerseView.baseBodyFontSize
        let numberFont = UIFont.systemFont(ofSize: 12 * scale)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: style.verseNumberColor,
        ]
        let widestNumber = "\(content.verses.map(\.verse).max() ?? 1)" as NSString
        let numberWidth = max(
            BibleVerseView.verseNumberColumnWidth(forBodyFontSize: style.font.pointSize),
            widestNumber.size(withAttributes: numberAttributes).width
        )
        let textIndent = ceil(numberWidth + BibleVerseView.verseNumberSpacing)
        let verseGap = 16 + style.lineSpacing

        for (index, verse) in content.verses.enumerated() {
            let isLast = index == content.verses.count - 1
            let compareText = content.compareTextByVerse[verse.verse].flatMap { $0.isEmpty ? nil : $0 }
            let blockStart = result.length

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = style.alignment
            paragraph.lineSpacing = style.lineSpacing
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = textIndent
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: textIndent)]
            paragraph.defaultTabInterval = textIndent
            paragraph.paragraphSpacing = compareText != nil ? 6 : (isLast ? 0 : verseGap)

            var number = numberAttributes
            number[.paragraphStyle] = paragraph
            result.append(NSAttributedString(string: "\(verse.verse)\t", attributes: number))
            // No trailing newline after the chapter's final paragraph: it would lay out an
            // empty line that can spill onto a blank extra page.
            let terminator = (isLast && compareText == nil) ? "" : "\n"
            result.append(NSAttributedString(
                string: (verse.verseText ?? "") + terminator,
                attributes: [.font: style.font, .foregroundColor: style.textColor, .paragraphStyle: paragraph]
            ))

            if let compareText {
                let compareParagraph = NSMutableParagraphStyle()
                compareParagraph.alignment = style.compareAlignment
                compareParagraph.lineSpacing = style.lineSpacing
                compareParagraph.firstLineHeadIndent = textIndent
                compareParagraph.headIndent = textIndent
                compareParagraph.paragraphSpacing = isLast ? 0 : verseGap
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
            verseOrder.append(verse.verse)
        }

        return (result, verseRanges, verseOrder, verseGap)
    }
}
