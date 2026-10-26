import Testing
import UIKit
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
        let creased = ChapterPaginator(content: content, style: style, pageSize: CGSize(width: 320, height: 500), exclusionRects: [band])
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

@Suite("Paged reader layout")
struct PagedReaderLayoutTests {
    @Test("Without a crease, landscape is a spread and portrait a single page")
    func orientationRule() {
        #expect(PagedReaderLayout.resolve(bounds: CGRect(x: 0, y: 0, width: 874, height: 360), divisionRegions: []).isSpread)
        #expect(!PagedReaderLayout.resolve(bounds: CGRect(x: 0, y: 0, width: 402, height: 780), divisionRegions: []).isSpread)
    }

    @Test("A vertical crease becomes the spine: spread centred on it, equal page widths, gutter half the crease")
    func verticalCreaseIsSpine() {
        let bounds = CGRect(x: 0, y: 0, width: 760, height: 740)
        let crease = CGRect(x: 370, y: 0, width: 20, height: 740)   // centre 380, right of the view's centre
        let layout = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [crease])
        #expect(layout.isSpread)
        #expect(layout.pageAreaFrame.midX == 380)
        #expect(layout.pageAreaFrame.width == 760)
        #expect(layout.spineGutter == 10)
        #expect(layout.exclusionBand == nil)

        let offCentre = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: [CGRect(x: 290, y: 0, width: 20, height: 740)])
        #expect(offCentre.pageAreaFrame.midX == 300)
        #expect(offCentre.pageAreaFrame.width == 600)
        #expect(offCentre.pageAreaFrame.minX == 0)
    }

    @Test("A horizontal crease keeps the orientation rule and becomes an exclusion band")
    func horizontalCreaseExcludes() {
        let layout = PagedReaderLayout.resolve(
            bounds: CGRect(x: 0, y: 0, width: 740, height: 760),
            divisionRegions: [CGRect(x: 0, y: 370, width: 740, height: 20)]
        )
        #expect(!layout.isSpread)
        #expect(layout.pageAreaFrame == CGRect(x: 0, y: 0, width: 740, height: 760))
        #expect(layout.exclusionBand == 370...390)
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
}

