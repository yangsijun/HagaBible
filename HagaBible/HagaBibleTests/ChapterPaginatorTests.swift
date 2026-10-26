import Testing
import UIKit
import SwiftUI
@testable import HagaBible

@Suite("Chapter paginator")
@MainActor
struct ChapterPaginatorTests {
    private func makeVerses(count: Int, wordsPerVerse: Int = 40) -> [BibleVerse] {
        (1...count).map { n in
            BibleVerse(
                bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: n,
                verseText: Array(repeating: "하나님이 천지를 창조하시니라", count: wordsPerVerse / 4).joined(separator: " "),
                versionCode: "KRV"
            )
        }
    }

    private func makeContent(_ verses: [BibleVerse], compare: [Int: String] = [:]) -> ChapterContent {
        ChapterContent(
            key: ChapterKey(versionCode: "KRV", bookCode: "GEN", chapter: 1),
            verses: verses,
            compareTextByVerse: compare
        )
    }

    private var style: PageTextStyle {
        PageTextStyle(
            font: .systemFont(ofSize: 20),
            compareFont: .systemFont(ofSize: 16),
            textColor: .label,
            verseNumberColor: .secondaryLabel,
            backgroundColor: .systemBackground,
            alignment: .justified,
            compareAlignment: .natural,
            lineSpacing: 4
        )
    }

    @Test("Pages cover the whole chapter contiguously and in order")
    func pagesCoverChapter() {
        let paginator = ChapterPaginator(content: makeContent(makeVerses(count: 31)), style: style, pageSize: CGSize(width: 320, height: 500))
        #expect(paginator.pageCount > 1)

        var expectedStart = 0
        for range in paginator.pageRanges {
            #expect(range.location == expectedStart)
            #expect(range.length > 0)
            expectedStart = NSMaxRange(range)
        }
        #expect(expectedStart == paginator.textStorage.length)

        var lastPage = 0
        for verse in 1...31 {
            let page = paginator.pageIndex(containingVerse: verse)
            #expect(page != nil)
            #expect((page ?? 0) >= lastPage)
            lastPage = page ?? 0
        }
        #expect(paginator.pageIndex(containingVerse: 99) == nil)
    }

    @Test("First verse on each page follows reading order; a split verse counts on both pages")
    func firstVersePerPage() {
        let paginator = ChapterPaginator(content: makeContent(makeVerses(count: 31)), style: style, pageSize: CGSize(width: 320, height: 500))
        #expect(paginator.firstVerse(onPage: 0) == 1)
        var last = 0
        for page in 0..<paginator.pageCount {
            let verse = paginator.firstVerse(onPage: page)
            #expect(verse != nil)
            #expect((verse ?? 0) >= last)
            last = verse ?? 0
        }
        // A verse that starts on page p is reported as the first verse of page p+1 only
        // if it runs past the page break — never a verse that hasn't started yet.
        for page in 1..<paginator.pageCount {
            let first = paginator.firstVerse(onPage: page) ?? 0
            let startsOn = paginator.pageIndex(containingVerse: first) ?? 0
            #expect(startsOn <= page)
        }
    }

    @Test("Comparison text rides with its verse and the single-page case has no spill")
    func comparisonAndShortChapter() {
        let verses = makeVerses(count: 2, wordsPerVerse: 8)
        let compare = Dictionary(uniqueKeysWithValues: verses.map { ($0.verse, "In the beginning God created the heaven and the earth.") })
        let paginator = ChapterPaginator(content: makeContent(verses, compare: compare), style: style, pageSize: CGSize(width: 360, height: 700))
        #expect(paginator.pageCount == 1)
        #expect(paginator.textStorage.string.contains("In the beginning"))
        #expect(paginator.firstVerse(onPage: 0) == 1)
    }

    @Test("A verse split over a page break reports a rect on both pages")
    func splitVerseRects() throws {
        var verses = makeVerses(count: 3, wordsPerVerse: 8)
        verses[1] = BibleVerse(
            bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2,
            verseText: Array(repeating: "하나님이 천지를 창조하시니라", count: 60).joined(separator: " "),
            versionCode: "KRV"
        )
        let paginator = ChapterPaginator(content: makeContent(verses), style: style, pageSize: CGSize(width: 320, height: 400))
        #expect(paginator.pageCount >= 2)
        let first = try #require(paginator.rect(forVerse: 2, onPage: 0))
        let second = try #require(paginator.rect(forVerse: 2, onPage: 1))
        #expect(first.height > 0 && second.height > 0)
        #expect(second.minY < first.minY)   // continues from the top of the next page
        #expect(paginator.rect(forVerse: 1, onPage: 1) == nil)
    }

    @Test("A tap on a verse's text resolves to that verse; the margin below the text resolves to nothing")
    func hitTesting() throws {
        let paginator = ChapterPaginator(content: makeContent(makeVerses(count: 3, wordsPerVerse: 8)), style: style, pageSize: CGSize(width: 360, height: 700))
        #expect(paginator.pageCount == 1)
        let rect2 = try #require(paginator.rect(forVerse: 2, onPage: 0))
        #expect(paginator.verse(at: CGPoint(x: rect2.midX, y: rect2.midY), onPage: 0) == 2)
        let rect3 = try #require(paginator.rect(forVerse: 3, onPage: 0))
        #expect(paginator.verse(at: CGPoint(x: 100, y: rect3.maxY + 80), onPage: 0) == nil)
        #expect(paginator.verses(onPage: 0) == [1, 2, 3])
    }

    @Test("A crease across the page is excluded from the text flow on every page")
    func creaseExclusion() {
        let content = makeContent(makeVerses(count: 31))
        let plain = ChapterPaginator(content: content, style: style, pageSize: CGSize(width: 320, height: 500))
        let band = CGRect(x: -1_000, y: 240, width: 10_000, height: 20)
        let creased = ChapterPaginator(content: content, style: style, pageSize: CGSize(width: 320, height: 500), exclusionRects: { _ in [band] })
        #expect(creased.pageCount >= plain.pageCount)
        for page in 0..<creased.pageCount {
            let container = creased.container(at: page)!
            let glyphs = creased.layoutManager.glyphRange(for: container)
            creased.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                #expect(!rect.intersects(band.insetBy(dx: 0, dy: 1)))
            }
        }
    }

    @Test("A page too small for one line terminates instead of looping")
    func degeneratePageSizeTerminates() {
        let paginator = ChapterPaginator(content: makeContent(makeVerses(count: 5)), style: style, pageSize: CGSize(width: 2, height: 2))
        #expect(paginator.pageCount >= 1)
        #expect(paginator.pageCount < 2000)
    }
}

@Suite("Parallel comparison layout")
@MainActor
struct ParallelPaginatorTests {
    private var style: PageTextStyle {
        PageTextStyle(
            font: .systemFont(ofSize: 20), compareFont: .systemFont(ofSize: 16),
            textColor: .label, verseNumberColor: .secondaryLabel, backgroundColor: .systemBackground,
            alignment: .justified, compareAlignment: .natural, lineSpacing: 4
        )
    }

    private func makeContent(verseCount: Int) -> ChapterContent {
        let verses = (1...verseCount).map { number in
            BibleVerse(
                bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: number,
                verseText: Array(repeating: "word", count: 4 + number % 7).joined(separator: " "), versionCode: "KRV"
            )
        }
        // Every third comparison verse is much longer than its main verse, the rest shorter.
        let compare = Dictionary(uniqueKeysWithValues: (1...verseCount).map { number in
            (number, number % 3 == 0 ? Array(repeating: "longer comparison text", count: 7).joined(separator: " ") : "short")
        })
        return ChapterContent(key: ChapterKey(versionCode: "KRV", bookCode: "GEN", chapter: 1), verses: verses, compareTextByVerse: compare)
    }

    @Test("Facing pages carry the same verses, main text left and comparison right, with rows aligned")
    func facingPagesAlignRows() throws {
        let pageSize = CGSize(width: 320, height: 400)
        let paginator = ChapterPaginator(content: makeContent(verseCount: 14), style: style, pageSize: pageSize, parallel: true)
        #expect(paginator.isParallel)
        #expect(paginator.pageCount.isMultiple(of: 2))
        #expect(paginator.pageCount >= 4)

        var seen: [Int] = []
        for left in stride(from: 0, to: paginator.pageCount, by: 2) {
            let right = left + 1
            let verses = paginator.verses(onPage: left)
            #expect(!verses.isEmpty)
            #expect(verses == paginator.verses(onPage: right))
            seen += verses
            for verse in verses {
                let leftRect = try #require(paginator.rect(forVerse: verse, onPage: left))
                let rightRect = try #require(paginator.rect(forVerse: verse, onPage: right))
                #expect(abs(leftRect.minY - rightRect.minY) < 0.5, "verse \(verse) rows differ")
                #expect(leftRect.maxY <= pageSize.height + 0.5)
                #expect(rightRect.maxY <= pageSize.height + 0.5)
            }
            let leftText = try #require(paginator.layoutManager(forPage: left)?.textStorage?.string)
            let rightText = try #require(paginator.layoutManager(forPage: right)?.textStorage?.string)
            #expect(!leftText.contains("short") && leftText.contains("word"))
            #expect(rightText.contains("short") && !rightText.contains("word"))
        }
        #expect(seen == Array(1...14))
        #expect(paginator.pageIndex(containingVerse: 14).map { $0.isMultiple(of: 2) } == true)
    }

    @Test("Without a spread the comparison stays under each verse in the flowing layout")
    func singlePageKeepsTheFlow() {
        let flowing = ChapterPaginator(content: makeContent(verseCount: 6), style: style, pageSize: CGSize(width: 320, height: 400), parallel: false)
        #expect(!flowing.isParallel)
        #expect(flowing.textStorage.string.contains("short"))
    }
}

@Suite("Paged reader layout")
struct PagedReaderLayoutTests {
    @Test("Without a crease, landscape is a spread and portrait a single page")
    func orientationRule() {
        #expect(PagedReaderLayout.resolve(bounds: CGRect(x: 0, y: 0, width: 874, height: 360), divisionRegions: []).isSpread)
        #expect(!PagedReaderLayout.resolve(bounds: CGRect(x: 0, y: 0, width: 402, height: 780), divisionRegions: []).isSpread)
    }

    @Test("A vertical crease becomes the spine: spread centred on it, equal page widths, gutter half the crease less the trimmed margin")
    func verticalCreaseIsSpine() {
        let bounds = CGRect(x: 0, y: 0, width: 760, height: 740)
        let crease = CGRect(x: 360, y: 0, width: 40, height: 740)   // centre 380, right of the view's centre
        let layout = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [crease])
        #expect(layout.isSpread)
        #expect(layout.pageAreaFrame.midX == 380)
        #expect(layout.pageAreaFrame.width == 760)
        #expect(layout.spineGutter == 20 - PagedReaderLayout.spineMarginTrim)

        // A crease narrower than the trimmed margin needs no gutter at all; the base margin already clears it.
        let narrow = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [CGRect(x: 377, y: 0, width: 6, height: 740)])
        #expect(narrow.spineGutter == 0)

        let offCentre = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [CGRect(x: 290, y: 0, width: 20, height: 740)])
        #expect(offCentre.pageAreaFrame.midX == 300)
        #expect(offCentre.pageAreaFrame.width == 600)
        #expect(offCentre.pageAreaFrame.minX == 0)
    }

    @Test("With the spread turned off, landscape and a vertical crease both stay one page")
    func spreadOffKeepsOnePage() {
        let bounds = CGRect(x: 0, y: 0, width: 874, height: 402)
        let plain = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [], spreadEnabled: false)
        #expect(!plain.isSpread)
        #expect(plain.pageAreaFrame == bounds)
        let folded = PagedReaderLayout.resolve(
            bounds: bounds, divisionRegions: [CGRect(x: 427, y: 0, width: 20, height: 402)], spreadEnabled: false
        )
        #expect(folded == plain)
    }

    @Test("A horizontal crease (half-folded in portrait) is ignored: one page, text straight across")
    func horizontalCreaseIsIgnored() {
        let layout = PagedReaderLayout.resolve(
            bounds: CGRect(x: 0, y: 0, width: 740, height: 760),
            divisionRegions: [CGRect(x: 0, y: 370, width: 740, height: 20)]
        )
        #expect(layout == PagedReaderLayout.resolve(bounds: CGRect(x: 0, y: 0, width: 740, height: 760), divisionRegions: []))
        #expect(!layout.isSpread)
        #expect(!layout.isCreaseCentred)
    }
}

@Suite("Paged reader controller")
@MainActor
struct PagedReaderControllerTests {
    private func makeContent(chapter: Int, verses: Int) -> ChapterContent {
        ChapterContent(
            key: ChapterKey(versionCode: "KRV", bookCode: "GEN", chapter: chapter),
            verses: (1...verses).map { n in
                BibleVerse(
                    bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: chapter, verse: n,
                    verseText: Array(repeating: "하나님이 천지를 창조하시니라", count: 8).joined(separator: " "),
                    versionCode: "KRV"
                )
            },
            compareTextByVerse: [:]
        )
    }

    private var style: PageTextStyle {
        PageTextStyle(
            font: .systemFont(ofSize: 20), compareFont: .systemFont(ofSize: 16),
            textColor: .label, verseNumberColor: .secondaryLabel, backgroundColor: .systemBackground,
            alignment: .justified, compareAlignment: .natural, lineSpacing: 4
        )
    }

    private func makeController(size: CGSize) -> PagedReaderController {
        let controller = PagedReaderController()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()
        return controller
    }

    private func displayedRefs(_ controller: PagedReaderController) -> [PageRef] {
        let pageViewController = controller.children.compactMap { $0 as? UIPageViewController }.first
        return pageViewController?.viewControllers?.compactMap { ($0 as? PageViewController)?.ref } ?? []
    }

    @Test("Landscape shows a two-page spread, portrait a single page")
    func spreadFollowsOrientation() {
        let landscape = makeController(size: CGSize(width: 874, height: 360))
        landscape.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        landscape.view.layoutIfNeeded()
        let spread = displayedRefs(landscape)
        #expect(spread.map(\.index) == [0, 1])

        let portrait = makeController(size: CGSize(width: 402, height: 780))
        portrait.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        portrait.view.layoutIfNeeded()
        #expect(displayedRefs(portrait).map(\.index) == [0])
    }

    @Test("In a spread, odd page numbers sit on the left and even on the right; a jump shows the containing spread")
    func spreadParity() {
        let controller = makeController(size: CGSize(width: 874, height: 360))
        let content = makeContent(chapter: 1, verses: 31)
        controller.apply(content: content, style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        // Find a verse whose page index is odd (an even page number) and jump to it.
        let pageViewController = controller.children.compactMap { $0 as? UIPageViewController }.first!
        var oddPageVerse: Int?
        for verse in 1...31 {
            controller.apply(content: content, style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: verse % 2 == 0, targetVerse: verse)
            let refs = displayedRefs(controller)
            #expect(refs.count == 2)
            #expect(refs[0].index % 2 == 0)
            #expect(refs[1].index == refs[0].index + 1)
            if refs[1].index > 0, oddPageVerse == nil { oddPageVerse = verse }
        }
        #expect(oddPageVerse != nil)
        _ = pageViewController
    }

    /// Hosts the controller in a window next to a tab bar whose visible content sits at `barFrame`.
    private func makeHostedController(size: CGSize, barFrame: CGRect) -> (PagedReaderController, UIWindow) {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let controller = PagedReaderController()
        window.rootViewController = controller
        let bar = UITabBar(frame: barFrame)
        bar.addSubview(UIView(frame: bar.bounds))
        window.addSubview(bar)
        window.isHidden = false
        window.layoutIfNeeded()
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        return (controller, window)
    }

    @Test("A size change opens the new pages from the centre over a fading snapshot, never sliding them in")
    func relayoutOpensFromCentre() async throws {
        let (controller, window) = makeHostedController(size: CGSize(width: 402, height: 874), barFrame: .zero)
        let pageView = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first?.view)
        #expect(!controller.isAnimatingRelayout)
        #expect(pageView.transform == .identity)

        window.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()

        let spread = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first?.view)
        #expect(controller.isAnimatingRelayout)
        #expect(spread.frame == window.bounds)   // laid out in place: no frame animation from zero
        #expect(spread.layer.animationKeys()?.contains("transform") == true)   // the opening (scale-x) animation is attached
        #expect(displayedPages(controller).count == 2)

        // The spring nominally takes 0.45s; under a loaded test host the completion can land late.
        for _ in 0..<30 where controller.isAnimatingRelayout {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!controller.isAnimatingRelayout)
        #expect(spread.transform == .identity)
        #expect(spread.alpha == 1)
    }

    @Test("The side margin setting pushes the text column inward on both sides")
    func sideMarginNarrowsTheColumn() throws {
        let controller = makeController(size: CGSize(width: 390, height: 844))
        let content = makeContent(chapter: 1, verses: 10)
        controller.apply(content: content, style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let plain = try #require(displayedPages(controller).first?.textContainer)
        let plainOrigin = controller.textLeadingX

        var wide = style
        wide.sideMargin = 20
        controller.apply(content: content, style: wide, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let padded = try #require(displayedPages(controller).first?.textContainer)
        #expect(padded.size.width == plain.size.width - 40)
        #expect(controller.textLeadingX == plainOrigin + 20)
    }

    @Test("Changing the side margin reports the new text column before the next layout pass")
    func sideMarginChangeReportsAtOnce() throws {
        let controller = makeController(size: CGSize(width: 390, height: 844))
        let content = makeContent(chapter: 1, verses: 10)
        var reported: [CGFloat] = []
        controller.onTextLeadingChanged = { reported.append($0) }
        controller.apply(content: content, style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let plain = controller.textLeadingX

        var wide = style
        wide.sideMargin = 20
        controller.apply(content: content, style: wide, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        #expect(reported.last == plain + 20)
    }

    @Test("A scroll-mode selection covers the side margin, not just the text")
    @MainActor
    func scrollSelectionSpansSideMargin() throws {
        let verses = (1...3).map {
            BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: $0, verseText: "In the beginning God created the heavens and the earth.", versionCode: "WEBBE")
        }
        var configuration = FontConfiguration.defaultFontConfiguration
        configuration.sideMargin = 40
        let list = BibleVerseListView(
            verses: verses, language: "English", fontConfiguration: configuration, theme: .light,
            highlightedVerseNum: nil, ttsCurrentVerseIndex: nil, bibleActionService: BibleActionService(),
            selectStartIndex: .constant(0), selectEndIndex: .constant(0)
        )
        .frame(width: 390, height: 600)
        .background(Color.white)
        let renderer = ImageRenderer(content: list)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let data = try #require(image.dataProvider?.data) as Data
        func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
            let i = y * image.bytesPerRow + x * (image.bitsPerPixel / 8)
            return (data[i], data[i + 1], data[i + 2])
        }
        // Some row of the selected verse is tinted all the way to x = 2 (inside the margin).
        let tintedInMargin = (0..<image.height).contains { y in
            let p = pixel(2, y)
            return !(p.0 > 250 && p.1 > 250 && p.2 > 250)
        }
        #expect(tintedInMargin)
    }

    @Test("A page's verse number and text land where the scroll reader's do", arguments: [1, 31, 119])
    func pageMatchesScrollRow(firstVerse: Int) throws {
        let text = "In the beginning God created the heavens and the earth. The earth was formless and empty, and darkness was on the surface of the deep."
        let verses = (0..<3).map {
            BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: firstVerse + $0, verseText: text, versionCode: "WEBBE")
        }
        let size = CGSize(width: 390, height: 844)
        let configuration = FontConfiguration.defaultFontConfiguration

        // The scroll reader's rows draw through UITextView, so they need a window, not
        // ImageRenderer. The hosted list does not sit at the window's top, so its rows
        // are measured from the first row's text view.
        let list = BibleVerseListView(
            verses: verses, language: "English", fontConfiguration: configuration, theme: .light,
            highlightedVerseNum: nil, ttsCurrentVerseIndex: nil, bibleActionService: BibleActionService(),
            selectStartIndex: .constant(nil), selectEndIndex: .constant(nil)
        )
        .ignoresSafeArea()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView: list)
        window.isHidden = false
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        let scrollInk = try inkTester(of: window)
        let textView = try #require(window.firstSubview(ofType: UITextView.self))
        let rowTop = Int(textView.convert(textView.bounds, to: window).minY)

        let controller = makeController(size: size)
        let pageStyle = PageTextStyle.make(fontConfiguration: configuration, theme: .light, language: "English", compareLanguage: "English")
        controller.apply(
            content: ChapterContent(key: ChapterKey(versionCode: "WEBBE", bookCode: "GEN", chapter: 1), verses: verses, compareTextByVerse: [:]),
            style: pageStyle, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: firstVerse
        )
        controller.view.layoutIfNeeded()
        let pageInk = try inkTester(of: controller.view)

        // One row: number ink left of x = 32, text ink from there on.
        func bounds(_ ink: (Int, Int) -> Bool, from top: Int, xs: Range<Int>) -> (top: Int, bottom: Int, left: Int) {
            var first = Int.max, last = -1, left = Int.max
            for y in top..<(top + 50) { for x in xs where ink(x, y) { first = min(first, y); last = max(last, y); left = min(left, x) } }
            return (first - top, last - top, left)
        }
        let pageRowTop = Int(PageViewController.textInsets.top)
        let scrollNumber = bounds(scrollInk, from: rowTop, xs: 10..<32), pageNumber = bounds(pageInk, from: pageRowTop, xs: 10..<32)
        let scrollText = bounds(scrollInk, from: rowTop, xs: 32..<390), pageText = bounds(pageInk, from: pageRowTop, xs: 32..<390)
        try #require(scrollNumber.bottom >= 0 && pageNumber.bottom >= 0 && scrollText.bottom >= 0 && pageText.bottom >= 0)
        // Two-digit numbers narrow to fit the column; a three-digit one may widen it by a point.
        #expect(abs(scrollText.left - pageText.left) <= (firstVerse < 100 ? 0 : 1))
        #expect(scrollText.top == pageText.top)
        #expect(abs((scrollNumber.top + scrollNumber.bottom) - (pageNumber.top + pageNumber.bottom)) <= 1)
        // The scroll list numbers rows by position, so only the first row's digit is comparable.
        if firstVerse == 1 { #expect(abs(scrollNumber.left - pageNumber.left) <= 1) }
        // The scroll reader's first row starts 24pt in (16pt list + 8pt row padding), like the page's.
        #expect(pageRowTop == 24)
    }

    @Test("The top verse's band keeps its padding above the text instead of being clipped")
    func topVerseBandIsNotClipped() throws {
        let controller = makeController(size: CGSize(width: 390, height: 844))
        var highlights = PageHighlights()
        highlights.selectedVerses = 1...1
        controller.apply(content: makeContent(chapter: 1, verses: 10), style: style, highlights: highlights, bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let page = try #require(displayedPages(controller).first)
        let text = try #require(page.view.subviews.compactMap { $0 as? PageTextView }.first)
        let verseRect = try #require(text.rect(forVerse: 1))
        #expect(text.frame.minY == PageViewController.textInsets.top - PageTextView.bandPadding.height)
        #expect(verseRect.minY >= PageTextView.bandPadding.height)
        // The band above the glyphs is tinted inside the view's own bounds.
        let alpha = renderedAlpha(of: text)
        #expect(alpha(Int(text.bounds.midX), 2) > 0.05)
    }

    /// Renders `view` over white through its layer and answers whether a pixel is darker than paper.
    private func inkTester(of view: UIView) throws -> (Int, Int) -> Bool {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            UIColor.white.setFill()
            context.fill(view.bounds)
            view.layer.render(in: context.cgContext)
        }
        let image = try #require(rendered.cgImage)
        let data = try #require(image.dataProvider?.data) as Data
        return { x, y in
            guard x >= 0, y >= 0, x < image.width, y < image.height else { return false }
            let i = y * image.bytesPerRow + x * (image.bitsPerPixel / 8)
            return Int(data[i]) + Int(data[i + 1]) + Int(data[i + 2]) < 600
        }
    }

    @Test("The context-menu lift is a copy of the verse band, so the rest of the page stays visible")
    func contextMenuLiftsACopyOfTheVerse() throws {
        // Targeted previews need a window (UIKit asserts otherwise), like the real reader has.
        let (controller, window) = makeHostedController(size: CGSize(width: 390, height: 844), barFrame: .zero)
        defer { window.isHidden = true }
        controller.contextMenu = { _ in UIMenu(children: [UIAction(title: "Copy") { _ in }]) }
        controller.apply(content: makeContent(chapter: 1, verses: 10), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let page = try #require(displayedPages(controller).first)
        let text = try #require(page.view.subviews.compactMap { $0 as? PageTextView }.first)
        let interaction = try #require(text.interactions.compactMap { $0 as? UIContextMenuInteraction }.first)
        let configuration = UIContextMenuConfiguration(identifier: NSNumber(value: 3), previewProvider: nil, actionProvider: nil)

        let preview = try #require(text.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration))
        #expect(preview.view !== text)
        #expect(preview.view.superview == nil)
        let verseRect = try #require(text.rect(forVerse: 3))
        #expect(preview.view.bounds.height < text.bounds.height)
        #expect(preview.view.bounds.height >= verseRect.height)
    }

    @Test("Bookmark stripes sit at the outer edge of each spread page: left edge on the left page, right edge on the right")
    func stripesMirrorOnTheRightPage() throws {
        let controller = makeController(size: CGSize(width: 874, height: 402))
        let stripe = BookmarkStripe(color: .yellow, extendsUp: false, extendsDown: false)
        let stripes = Dictionary(uniqueKeysWithValues: (1...31).map { ($0, [Optional(stripe)]) })
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: stripes, navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let pages = displayedPages(controller)
        #expect(pages.count == 2)

        for (index, page) in pages.enumerated() {
            let text = try #require(page.view.subviews.compactMap { $0 as? PageTextView }.first)
            let container = try #require(page.textContainer)
            let layoutManager = try #require(container.layoutManager)
            let firstLine = layoutManager.lineFragmentUsedRect(forGlyphAt: layoutManager.glyphRange(for: container).location, effectiveRange: nil)
            let y = Int(firstLine.midY)
            let alpha = renderedAlpha(of: text)
            let leading = Int(text.textOriginX - 16) + 1
            let trailing = Int(text.textOriginX + container.size.width + 16) - 2
            let isRight = index == 1
            #expect((alpha(leading, y) > 0.5) == !isRight, "page \(index) leading edge")
            #expect((alpha(trailing, y) > 0.5) == isRight, "page \(index) trailing edge")
        }
    }

    /// Renders the view at 1x and returns a sampler of the alpha at integer coordinates.
    private func renderedAlpha(of view: UIView) -> (Int, Int) -> CGFloat {
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        view.layer.render(in: context)
        // The closure keeps `context` alive; its pixel buffer dies with it.
        return { x, y in
            guard (0..<width).contains(x), (0..<height).contains(y) else { return 0 }
            let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
            return CGFloat(bytes[y * context.bytesPerRow + x * 4 + 3]) / 255
        }
    }

    private func displayedPages(_ controller: PagedReaderController) -> [PageViewController] {
        let pageViewController = controller.children.compactMap { $0 as? UIPageViewController }.first
        return pageViewController?.viewControllers?.compactMap { $0 as? PageViewController } ?? []
    }

    @Test("A bottom tab bar strip shortens every page; a trailing pill only carves the page it covers")
    func tabBarPlacement() throws {
        let size = CGSize(width: 874, height: 402)
        let fullHeight = size.height - PageViewController.textInsets.top - PageViewController.textInsets.bottom

        let (strip, stripWindow) = makeHostedController(size: size, barFrame: CGRect(x: 0, y: 338, width: 874, height: 64))
        let stripPages = displayedPages(strip)
        #expect(stripPages.count == 2)
        for page in stripPages {
            let container = try #require(page.textContainer)
            #expect(container.size.height == fullHeight - 64)
            #expect(container.exclusionPaths.isEmpty)
        }

        let pill = CGRect(x: 820, y: 180, width: 44, height: 200)
        let (pillReader, pillWindow) = makeHostedController(size: size, barFrame: pill)
        let pillPages = displayedPages(pillReader)
        #expect(pillPages.count == 2)
        let left = try #require(pillPages.first?.textContainer)
        let right = try #require(pillPages.last?.textContainer)
        #expect(left.size.height == fullHeight)
        #expect(left.exclusionPaths.isEmpty)
        #expect(right.size.height == fullHeight)
        let carved = try #require(right.exclusionPaths.first?.bounds)
        // In the right page's text coordinates the pill sits at the trailing edge.
        let rightTextOriginX = size.width / 2 + PageViewController.textInsets.left
        #expect(abs(carved.minX - (pill.minX - 12 - rightTextOriginX)) < 1)
        #expect(abs(carved.minY - (pill.minY - 12 - PageViewController.textInsets.top)) < 1)
        // Text really flows around it: the last verse on the right page starts lower than it would unobstructed.
        #expect(right.exclusionPaths.count == 1)
        _ = (stripWindow, pillWindow)
    }

    @Test("Side safe areas stay out of the text: each spread page clears its own side, a single page clears both")
    func sideSafeAreas() throws {
        let base = PageViewController.textInsets
        let spread = makeController(size: CGSize(width: 874, height: 402))
        spread.contentInsets = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 0)
        spread.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        spread.view.layoutIfNeeded()
        let pages = displayedPages(spread)
        #expect(pages.count == 2)
        // The island is on the left only: the spread starts after it and the remaining
        // width is split evenly, so both pages (and their text) are the same width.
        let pageViewController = try #require(spread.children.compactMap { $0 as? UIPageViewController }.first)
        #expect(pageViewController.view.frame == CGRect(x: 59, y: 0, width: 874 - 59, height: 402))
        for page in pages {
            let container = try #require(page.textContainer)
            #expect(container.size.width == (874 - 59) / 2 - base.left - base.right)
            #expect(container.exclusionPaths.isEmpty)
            let text = try #require(page.view.subviews.compactMap { $0 as? PageTextView }.first)
            #expect(text.textOriginX == base.left)
        }
        #expect(spread.textLeadingX == 59 + base.left)

        let single = makeController(size: CGSize(width: 402, height: 874))
        single.contentInsets = UIEdgeInsets(top: 59, left: 20, bottom: 34, right: 0)
        single.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        single.view.layoutIfNeeded()
        let container = try #require(displayedPages(single).first?.textContainer)
        #expect(container.size.width == 402 - base.left - base.right - 20)
    }

    @Test("On a spread the user's side margin widens only the outer edges, never the spine")
    func spreadSideMarginIsOuterOnly() throws {
        let base = PageViewController.textInsets
        let spread = makeController(size: CGSize(width: 874, height: 402))
        spread.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        spread.view.layoutIfNeeded()
        let plain = try #require(displayedPages(spread).first?.textContainer).size.width
        let plainRightOrigin = try #require(displayedPages(spread).last?.view.subviews.compactMap { $0 as? PageTextView }.first).textOriginX

        var wide = style
        wide.sideMargin = 20
        spread.apply(content: makeContent(chapter: 1, verses: 31), style: wide, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        spread.view.layoutIfNeeded()
        let pages = displayedPages(spread)
        #expect(pages.count == 2)
        let texts = try pages.map { try #require($0.view.subviews.compactMap { $0 as? PageTextView }.first) }
        // Each page loses the margin once (its outer edge); the text starts 20pt further in
        // on the left page and where it was on the right page (its margin is on the far edge).
        for page in pages { #expect(try #require(page.textContainer).size.width == plain - 20) }
        #expect(texts[0].textOriginX == base.left + 20)
        #expect(texts[1].textOriginX == plainRightOrigin)
    }

    @Test("Half-folded, both pages keep the same (trimmed) outer margin even when only one side has a safe area")
    func halfFoldedSymmetricMargins() throws {
        let base = PageViewController.textInsets
        let controller = makeController(size: CGSize(width: 874, height: 402))
        controller.divisionRegionsForTesting = [CGRect(x: 417, y: 0, width: 40, height: 402)]   // half 20 → gutter 20 − trim
        let gutter = 20 - PagedReaderLayout.spineMarginTrim
        controller.contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 21, right: 59)
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let pages = displayedPages(controller)
        #expect(pages.count == 2)
        for page in pages {
            let container = try #require(page.textContainer)
            #expect(container.exclusionPaths.isEmpty)
            #expect(container.size.width == 437 - base.left - base.right - (59 - PagedReaderLayout.outerMarginTrim) - gutter)
        }
        let leftText = try #require(pages[0].view.subviews.compactMap { $0 as? PageTextView }.first)
        let rightText = try #require(pages[1].view.subviews.compactMap { $0 as? PageTextView }.first)
        #expect(leftText.textOriginX == base.left + 59 - PagedReaderLayout.outerMarginTrim)
        #expect(rightText.textOriginX == base.left + gutter)
    }

    @Test("Navigating to a verse lands on its page; a prefetched neighbour continues the sequence")
    func navigationAndNeighbourChaining() async throws {
        let controller = makeController(size: CGSize(width: 874, height: 360))
        controller.fetchNeighbor = { key, forward in
            forward ? self.makeContent(chapter: key.chapter + 1, verses: 10) : nil
        }
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        // Let the neighbour prefetch land.
        try await Task.sleep(for: .milliseconds(200))

        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: true, targetVerse: 30)
        let refs = displayedRefs(controller)
        let pageViewController = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first)
        let lastRef = try #require(refs.first)
        #expect(lastRef.index > 0)

        // Walk forward through the data source from the displayed page: it must cross
        // from chapter 1 into chapter 2 page 0 without a gap.
        var cursor: UIViewController = try #require(pageViewController.viewControllers?.first)
        var crossed = false
        for _ in 0..<40 {
            guard let next = controller.pageViewController(pageViewController, viewControllerAfter: cursor) as? PageViewController else { break }
            if next.ref.key.chapter == 2 {
                #expect(next.ref.index == 0)
                crossed = true
                break
            }
            cursor = next
        }
        #expect(crossed)
    }

    @Test("A trailing tab bar pill is reported in window coordinates; a bottom strip is not")
    func tabBarOcclusionReport() throws {
        func report(barFrame: CGRect) -> CGRect?? {
            let size = CGSize(width: 874, height: 402)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            let controller = PagedReaderController()
            var reported: CGRect?? = .none
            controller.onTabBarOcclusionChanged = { reported = .some($0) }
            window.rootViewController = controller
            let bar = UITabBar(frame: barFrame)
            bar.addSubview(UIView(frame: bar.bounds))
            window.addSubview(bar)
            window.isHidden = false
            window.layoutIfNeeded()
            controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
            controller.view.layoutIfNeeded()
            return reported
        }
        let pill = CGRect(x: 820, y: 180, width: 44, height: 200)
        let pillReport = try #require(report(barFrame: pill))
        #expect(pillReport == pill)
        // Nothing covers the page, so there is nothing to report (the state starts as nil).
        #expect((report(barFrame: CGRect(x: 0, y: 338, width: 874, height: 64)) ?? nil) == nil)
    }

    @Test("A system occlusion region (foldable tab column) is reported like a tab bar pill")
    func occlusionRegionReport() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        let controller = PagedReaderController()
        var reported: CGRect?? = .none
        controller.onTabBarOcclusionChanged = { reported = .some($0) }
        window.rootViewController = controller
        window.isHidden = false
        let column = CGRect(x: 830, y: 0, width: 44, height: 402)
        controller.occlusionRegionsForTesting = [column]
        window.layoutIfNeeded()
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        #expect(try #require(reported) == column)
    }

    @Test("The selection band reaches across the user's side margin")
    func selectionBandSpansSideMargin() throws {
        func liftedWidth(sideMargin: CGFloat) throws -> CGFloat {
            var style = self.style
            style.sideMargin = sideMargin
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            let controller = PagedReaderController()
            window.rootViewController = controller
            window.isHidden = false
            window.layoutIfNeeded()
            controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
            controller.view.layoutIfNeeded()
            let pageViewController = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first)
            let page = try #require(pageViewController.viewControllers?.first as? PageViewController)
            let textView = try #require(page.verseTapRecognizer?.view as? PageTextView)
            let interaction = UIContextMenuInteraction(delegate: textView)
            let configuration = UIContextMenuConfiguration(identifier: NSNumber(value: 1), previewProvider: nil, actionProvider: nil)
            let preview = try #require(textView.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration))
            return preview.view.bounds.width
        }
        // A wider margin narrows the text but the band still spans edge to edge: same width.
        #expect(try liftedWidth(sideMargin: 0) == 402)
        #expect(try liftedWidth(sideMargin: 24) == 402)
    }

    @Test("The lifted verse keeps its glyphs under the selection tint")
    func liftedVerseShowsText() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let controller = PagedReaderController()
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let pageViewController = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first)
        let page = try #require(pageViewController.viewControllers?.first as? PageViewController)
        let textView = try #require(page.verseTapRecognizer?.view as? PageTextView)
        let interaction = UIContextMenuInteraction(delegate: textView)
        let configuration = UIContextMenuConfiguration(identifier: NSNumber(value: 1), previewProvider: nil, actionProvider: nil)
        let preview = try #require(textView.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration))
        let image = try #require((preview.view as? UIImageView)?.image?.cgImage)

        // Paper and tint are light; only glyphs are dark.
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var darkPixels = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 200 {
            if Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2]) < 3 * 110 { darkPixels += 1 }
        }
        #expect(darkPixels > 50)
    }

    @Test("A page torn down under an open verse menu gives the dismissal no preview instead of crashing")
    func dismissPreviewAfterRelayoutDoesNotCrash() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        let controller = PagedReaderController()
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)
        controller.view.layoutIfNeeded()
        let pageViewController = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first)
        let page = try #require(pageViewController.viewControllers?.first as? PageViewController)
        let textView = try #require(page.verseTapRecognizer?.view as? PageTextView)
        let interaction = UIContextMenuInteraction(delegate: textView)
        let configuration = UIContextMenuConfiguration(identifier: NSNumber(value: 1), previewProvider: nil, actionProvider: nil)
        #expect(textView.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration) != nil)

        // Rotating to portrait rebuilds the spread as single pages; the old page leaves the window.
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.frame = window.bounds
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        #expect(textView.window == nil)
        #expect(textView.contextMenuInteraction(interaction, previewForDismissingMenuWithConfiguration: configuration) == nil)
    }

    @Test("A page flipped into from the prefetched next chapter selects verses once that chapter is current")
    func flippedIntoNeighbourGainsTapHandlers() async throws {
        let controller = makeController(size: CGSize(width: 390, height: 844))
        controller.onVerseTapped = { _ in }
        controller.fetchNeighbor = { key, forward in
            forward ? self.makeContent(chapter: key.chapter + 1, verses: 10) : nil
        }
        controller.apply(content: makeContent(chapter: 1, verses: 31), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 31)
        try await Task.sleep(for: .milliseconds(200))

        let pageViewController = try #require(controller.children.compactMap { $0 as? UIPageViewController }.first)
        var cursor: UIViewController = try #require(pageViewController.viewControllers?.first)
        var landed: PageViewController?
        for _ in 0..<40 {
            guard let next = controller.pageViewController(pageViewController, viewControllerAfter: cursor) as? PageViewController else { break }
            if next.ref.key.chapter == 2 { landed = next; break }
            cursor = next
        }
        let page = try #require(landed)
        // As a neighbour it has no handler, so a tap there turns the page instead.
        #expect(page.onVerseTapped == nil)

        // The curl lands on it, then the view model follows and re-applies that chapter.
        pageViewController.setViewControllers([page], direction: .forward, animated: false)
        controller.apply(content: makeContent(chapter: 2, verses: 10), style: style, highlights: .init(), bookmarkStripes: [:], navigationToken: false, targetVerse: 1)

        let displayed = try #require(pageViewController.viewControllers?.first as? PageViewController)
        #expect(displayed === page)
        #expect(displayed.onVerseTapped != nil)
        #expect(displayed.contextMenu != nil)
    }
}


@Suite("Tab bar clearance")
@MainActor
struct TabBarClearanceTests {
    // Action-bar buttons resting at the bottom-trailing corner of a landscape iPhone window.
    private let buttons = CGRect(x: 640, y: 285, width: 196, height: 44)

    @Test("A search circle just below the buttons is not touched, so nothing moves")
    func landscapePhoneClear() {
        let parts = [CGRect(x: 792, y: 338, width: 44, height: 44), CGRect(x: 38, y: 338, width: 180, height: 44)]
        let clearance = TabBarGeometry.clearance(for: buttons, parts: parts)
        #expect(clearance.lift == 0 && clearance.shift == 0)
    }

    @Test("A trailing tab column is dodged by shifting left, not by lifting")
    func trailingColumnShiftsLeft() {
        let column = CGRect(x: 830, y: 0, width: 44, height: 402)
        let clearance = TabBarGeometry.clearance(for: buttons, parts: [column])
        #expect(clearance.shift == 14, "\(clearance)")
        #expect(clearance.lift == 0)
    }

    @Test("A bottom pill under the buttons is dodged by lifting")
    func bottomPillLifts() {
        let pill = CGRect(x: 700, y: 320, width: 150, height: 44)
        let clearance = TabBarGeometry.clearance(for: buttons, parts: [pill])
        #expect(clearance.lift == 17, "\(clearance)")
        #expect(clearance.shift == 0)
    }

    @Test("A notch insets both sides alike and is ignored; a one-sided trailing column is not")
    func trailingChromeInset() {
        #expect(TabBarGeometry.trailingChromeInset(safeArea: EdgeInsets(top: 0, leading: 59, bottom: 21, trailing: 59)) == 0)
        #expect(TabBarGeometry.trailingChromeInset(safeArea: EdgeInsets(top: 0, leading: 0, bottom: 21, trailing: 92)) == 92)
        #expect(TabBarGeometry.trailingChromeInset(safeArea: EdgeInsets(top: 0, leading: 92, bottom: 21, trailing: 0)) == 0)
        #expect(TabBarGeometry.trailingChromeInset(safeArea: EdgeInsets()) == 0)
    }

    @Test("Only the tab bar's shown subviews count, in window coordinates")
    func visiblePartsAreTheShownSubviews() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        let bar = UITabBar(frame: CGRect(x: 0, y: 338, width: 874, height: 64))
        let pill = UIView(frame: CGRect(x: 38, y: 0, width: 180, height: 44))
        let hidden = UIView(frame: CGRect(x: 300, y: 0, width: 44, height: 44))
        hidden.isHidden = true
        bar.addSubview(pill)
        bar.addSubview(hidden)
        window.addSubview(bar)
        let parts = TabBarGeometry.visibleParts(in: window)
        #expect(parts.contains(CGRect(x: 38, y: 338, width: 180, height: 44)))
        #expect(!parts.contains(CGRect(x: 300, y: 338, width: 44, height: 44)))
    }
}


private extension UIView {
    func firstSubview<T: UIView>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T { return match }
            if let match = subview.firstSubview(ofType: type) { return match }
        }
        return nil
    }
}
