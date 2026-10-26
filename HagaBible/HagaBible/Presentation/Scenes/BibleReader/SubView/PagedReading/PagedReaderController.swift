//
//  PagedReaderController.swift
//  HagaBible
//

import SwiftUI
import UIKit

/// A page's place: a chapter slot and a page index inside it. In a spread, index
/// `pageCount` of a chapter with an odd page count is a blank filler, so every chapter
/// starts on a left-hand page and the facing page of a chapter's last page never shows
/// the next chapter (see `nextRef(after:)`).
struct PageRef: Hashable {
    let key: ChapterKey
    let index: Int
}

/// Which half of a spread a page is on. In a spread, even page indices (odd page
/// numbers) are left-hand pages and odd indices right-hand; fillers pad every chapter to
/// an even length so the rule holds across chapters.
enum PageSide {
    case single, left, right
}

/// Where the pages go inside the reader, derived from the view's size and any fold
/// crease (`UIView.reservedRegions(kind: .division)`, iOS 27.1, foldable iPhone).
///
/// - A crease running top-to-bottom becomes the book's spine: a two-page spread centred
///   on it, with the page area shrunk symmetrically so both pages are the same width,
///   and a gutter on each page's spine side so no text sits under the crease.
/// - A crease running left-to-right can't be a spine; text flows around it instead
///   (`exclusionBand` becomes an exclusion path on every page).
/// - Without a crease, landscape (wider than tall) is a spread, portrait a single page.
struct PagedReaderLayout: Equatable {
    var pageAreaFrame: CGRect
    var isSpread: Bool
    /// Extra inset on a page's spine side: half the crease width (0 without a spine crease).
    var spineGutter: CGFloat = 0
    /// Vertical band (page-area coordinates) text must avoid on every page.
    var exclusionBand: ClosedRange<CGFloat>?

    static func resolve(bounds: CGRect, divisionRegions: [CGRect]) -> PagedReaderLayout {
        let regions = divisionRegions.filter { !$0.isEmpty && $0.intersects(bounds) }
        if let crease = regions.first(where: { $0.height > $0.width }) {
            let center = crease.midX
            let half = min(center - bounds.minX, bounds.maxX - center)
            // A crease near an edge can't carry a readable spread; ignore it.
            guard half >= 160 else { return fallback(bounds) }
            return PagedReaderLayout(
                pageAreaFrame: CGRect(x: center - half, y: bounds.minY, width: half * 2, height: bounds.height),
                isSpread: true,
                spineGutter: ceil(crease.width / 2)
            )
        }
        var layout = fallback(bounds)
        if let crease = regions.first(where: { $0.width >= $0.height }) {
            layout.exclusionBand = (crease.minY - bounds.minY)...(crease.maxY - bounds.minY)
        }
        return layout
    }

    private static func fallback(_ bounds: CGRect) -> PagedReaderLayout {
        PagedReaderLayout(pageAreaFrame: bounds, isSpread: bounds.width > bounds.height)
    }
}

/// Highlight bands drawn behind verses of the current chapter (verse numbers).
struct PageHighlights: Equatable {
    var navigatedVerse: Int?
    var ttsVerseIndex: Int?
    /// Selected verse numbers (tap-to-select, same rules as the scroll reader).
    var selectedVerses: ClosedRange<Int>?
}

/// Book-style reader: a `UIPageViewController` with the page-curl transition, one page
/// in portrait and a two-page spread (spine in the middle) in landscape.
///
/// The view covers the whole screen (under the bars) so the curl is full-screen; the
/// text sits inside `contentInsets` (the safe area) plus the page margins.
///
/// Three chapters are kept typeset at a time — the previous, the current and the next —
/// so a flip at a chapter's last page curls straight into the next chapter's first page.
/// When a flip lands in a neighbouring chapter the owner is told (`onPageChanged`), moves
/// the view model there, and the content that comes back matches the neighbour slot, so
/// the window just shifts; nothing on screen is rebuilt.
@MainActor
final class PagedReaderController: UIViewController {
    typealias Highlights = PageHighlights

    /// Supplies the chapter before/after `key` in reading order (`nil` at either end of the Bible).
    var fetchNeighbor: ((ChapterKey, _ forward: Bool) async -> ChapterContent?)?
    /// Fired after a user flip settles, with the first verse on the (left) page.
    var onPageChanged: ((ChapterKey, _ firstVerse: Int) -> Void)?
    /// Fired on any page-turn gesture; the owner uses it to hold off screen dimming.
    var onUserInteraction: (() -> Void)?
    /// A tap on a verse of the current chapter (verse number).
    var onVerseTapped: ((Int) -> Void)?
    /// Long-press menu for a verse of the current chapter (verse number); `nil` for none.
    var contextMenu: ((Int) -> UIMenu?)?

    /// Screen regions the text must stay out of (the safe area, since the view itself
    /// extends under the bars). Changing it re-typesets.
    var contentInsets: UIEdgeInsets = .zero {
        didSet { if contentInsets != oldValue { view.setNeedsLayout() } }
    }

    private struct Slot {
        var content: ChapterContent
        var paginator: ChapterPaginator?
    }

    private var previousSlot: Slot?
    private var currentSlot: Slot?
    private var nextSlot: Slot?

    private var style: PageTextStyle?
    private var highlights = PageHighlights()
    private var bookmarkStripes: [Int: [BookmarkStripe?]] = [:]
    private var lastNavigationToken: Bool?
    /// Verse to land on once the view has a size (content can arrive before layout).
    private var pendingLandingVerse: Int?

    private var pageViewController: UIPageViewController?
    private var layout: PagedReaderLayout?
    /// The insets the current pagination was computed with; a change re-typesets.
    private var paginatedInsets: UIEdgeInsets = .zero
    private var isTransitioning = false

    private var isSpread: Bool { layout?.isSpread ?? false }

    /// Size of one page (half the page area in a spread). Zero until the first layout.
    private var pageSize: CGSize {
        guard let layout else { return .zero }
        let area = layout.pageAreaFrame.size
        return CGSize(width: layout.isSpread ? area.width / 2 : area.width, height: area.height)
    }

    /// Bottom strip covered by the tab bar, measured at the last layout. The safe area
    /// already excludes it in portrait, but in landscape (tab bar in the trailing corner)
    /// it does not, and text must still stay clear of it.
    private var tabBarReserve: CGFloat = 0

    /// Margins around a page's text, before the spine gutter.
    private var textInsets: UIEdgeInsets {
        let base = PageViewController.textInsets
        return UIEdgeInsets(
            top: base.top + contentInsets.top,
            left: base.left,
            bottom: base.bottom + max(contentInsets.bottom, tabBarReserve),
            right: base.right
        )
    }

    /// Tallest strip a bottom tab bar can plausibly take; anything else found in the
    /// window (a hidden/top-anchored bar) is ignored rather than blanking the pages.
    private static let maxTabBarReserve: CGFloat = 120

    /// How far a visible bottom tab bar overlapping this view reaches up into it. The
    /// bar's own frame is not trusted (it can be a strip, or the whole window, depending
    /// on the OS); the strip is taken from its visible content views instead.
    private func measureTabBarReserve() -> CGFloat {
        guard let window = view.window else { return 0 }
        let candidates = Self.tabBars(in: window).compactMap { bar -> CGFloat? in
            guard !bar.isHidden, bar.alpha > 0 else { return nil }
            let contentFrames = bar.subviews
                .filter { !$0.isHidden && $0.alpha > 0 && !$0.bounds.isEmpty }
                .map { $0.convert($0.bounds, to: view) }
            let frame = contentFrames.dropFirst().reduce(contentFrames.first ?? bar.convert(bar.bounds, to: view)) { $0.union($1) }
            guard frame.intersects(view.bounds), frame.minY >= view.bounds.maxY - Self.maxTabBarReserve else { return nil }
            return view.bounds.maxY - frame.minY
        }
        return candidates.max() ?? 0
    }

    private static func tabBars(in view: UIView) -> [UITabBar] {
        var found: [UITabBar] = []
        if let bar = view as? UITabBar { found.append(bar) }
        for subview in view.subviews { found += tabBars(in: subview) }
        return found
    }

    /// Text area of one page. The gutter is taken once (it lands on the spine side), so
    /// both halves of a spread share one text width. Never collapses: if the insets
    /// would leave no room (an unexpected crease or bar measurement), the page falls
    /// back to its base margins rather than typesetting nothing.
    private var textSize: CGSize {
        let insets = textInsets
        let base = PageViewController.textInsets
        var size = CGSize(
            width: pageSize.width - insets.left - insets.right - (layout?.spineGutter ?? 0),
            height: pageSize.height - insets.top - insets.bottom
        )
        if size.width < 120 { size.width = pageSize.width - base.left - base.right }
        if size.height < 120 { size.height = pageSize.height - base.top - base.bottom }
        return size
    }

    /// The crease band translated into page text coordinates (same on every page since
    /// the band spans the whole width).
    private var exclusionRects: [CGRect] {
        guard let band = layout?.exclusionBand else { return [] }
        let top = band.lowerBound - textInsets.top
        return [CGRect(x: -1_000, y: top, width: 10_000, height: band.upperBound - band.lowerBound)]
    }

    // MARK: - Input

    func apply(
        content: ChapterContent,
        style: PageTextStyle,
        highlights: PageHighlights,
        bookmarkStripes: [Int: [BookmarkStripe?]],
        navigationToken: Bool,
        targetVerse: Int
    ) {
        let styleChanged = self.style != style
        self.style = style
        view.backgroundColor = style.backgroundColor
        var landingVerse: Int?

        if let slot = currentSlot, slot.content.key == content.key {
            if styleChanged || slot.content != content {
                landingVerse = currentFirstVisibleVerse() ?? targetVerse
                replaceCurrent(with: content, styleChanged: styleChanged)
            }
        } else if let slot = nextSlot, slot.content.key == content.key {
            // The user flipped forward into the prefetched chapter.
            previousSlot = currentSlot
            currentSlot = slot
            nextSlot = nil
            if styleChanged || slot.content != content {
                landingVerse = currentFirstVisibleVerse() ?? targetVerse
                replaceCurrent(with: content, styleChanged: styleChanged)
            }
            fetchNeighborIfNeeded(forward: true)
        } else if let slot = previousSlot, slot.content.key == content.key {
            nextSlot = currentSlot
            currentSlot = slot
            previousSlot = nil
            if styleChanged || slot.content != content {
                landingVerse = currentFirstVisibleVerse() ?? targetVerse
                replaceCurrent(with: content, styleChanged: styleChanged)
            }
            fetchNeighborIfNeeded(forward: false)
        } else {
            // A chapter we don't have: first load, navigation, or a version switch.
            previousSlot = nil
            nextSlot = nil
            currentSlot = makeSlot(content)
            landingVerse = targetVerse
            fetchNeighborIfNeeded(forward: true)
            fetchNeighborIfNeeded(forward: false)
        }

        if let lastNavigationToken, lastNavigationToken != navigationToken {
            // Explicit navigation (navigation sheet, search, bookmark, App Intent).
            landingVerse = targetVerse
        }
        lastNavigationToken = navigationToken

        let previousHighlights = self.highlights
        self.highlights = highlights
        self.bookmarkStripes = bookmarkStripes

        if let landingVerse {
            if pageSize == .zero || isTransitioning {
                // Applied once the view has a size / the flip in flight has settled;
                // replacing the pages under a running curl breaks the page view controller.
                pendingLandingVerse = landingVerse
            } else {
                display(pageContaining: landingVerse, animated: false)
            }
        } else if highlights.ttsVerseIndex != previousHighlights.ttsVerseIndex {
            followTTS()
        }
        redrawDisplayedPages()
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let newLayout = PagedReaderLayout.resolve(bounds: bounds, divisionRegions: divisionRegionFrames())
        let newReserve = measureTabBarReserve()
        guard newLayout != layout || pageViewController == nil || paginatedInsets != contentInsets || newReserve != tabBarReserve else { return }

        let landingVerse = pendingLandingVerse ?? currentFirstVisibleVerse()
        pendingLandingVerse = nil
        let spreadChanged = newLayout.isSpread != layout?.isSpread
        layout = newLayout
        paginatedInsets = contentInsets
        tabBarReserve = newReserve
        if spreadChanged || pageViewController == nil {
            rebuildPageViewController()
        }
        pageViewController?.view.frame = newLayout.pageAreaFrame
        repaginateAllSlots()
        if let landingVerse {
            display(pageContaining: landingVerse, animated: false)
        } else if currentSlot != nil {
            display(pageContaining: 1, animated: false)
        }
    }

    /// Active fold creases in the view's coordinates (foldable iPhone, iOS 27.1+). The
    /// physical crease only: the region's frame also carries recommended margins, which
    /// would double the gutter on a half-folded device.
    private func divisionRegionFrames() -> [CGRect] {
        if #available(iOS 27.1, *) {
            return view.reservedRegions(kind: .division)
                .filter(\.isActive)
                .map { region in
                    let crease = region.frame.inset(by: region.margins)
                    return crease.isNull || crease.width <= 0 || crease.height <= 0 ? region.frame : crease
                }
        }
        return []
    }

    private func rebuildPageViewController() {
        if let old = pageViewController {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        let spine: UIPageViewController.SpineLocation = isSpread ? .mid : .min
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: spine.rawValue)]
        )
        // Required for a mid spine: the back of a curling leaf shows the following page.
        controller.isDoubleSided = isSpread
        controller.dataSource = self
        controller.delegate = self
        controller.view.backgroundColor = .clear
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        pageViewController = controller
        isTransitioning = false
    }

    // MARK: - Slots

    private func makeSlot(_ content: ChapterContent) -> Slot {
        var slot = Slot(content: content, paginator: nil)
        paginate(&slot)
        return slot
    }

    private func paginate(_ slot: inout Slot) {
        guard let style, pageSize != .zero else {
            slot.paginator = nil
            return
        }
        slot.paginator = ChapterPaginator(content: slot.content, style: style, pageSize: textSize, exclusionRects: exclusionRects)
    }

    private func replaceCurrent(with content: ChapterContent, styleChanged: Bool) {
        currentSlot = makeSlot(content)
        if styleChanged {
            // Neighbours keep their text and are just re-typeset.
            if var slot = previousSlot { paginate(&slot); previousSlot = slot }
            if var slot = nextSlot { paginate(&slot); nextSlot = slot }
        } else {
            // Same chapter, different text (comparison toggled): the neighbours' text is
            // stale in the same way, so drop and refetch them.
            previousSlot = nil
            nextSlot = nil
            fetchNeighborIfNeeded(forward: true)
            fetchNeighborIfNeeded(forward: false)
        }
    }

    private func repaginateAllSlots() {
        if var slot = previousSlot { paginate(&slot); previousSlot = slot }
        if var slot = currentSlot { paginate(&slot); currentSlot = slot }
        if var slot = nextSlot { paginate(&slot); nextSlot = slot }
    }

    private func fetchNeighborIfNeeded(forward: Bool) {
        guard let currentSlot, (forward ? nextSlot : previousSlot) == nil, let fetchNeighbor else { return }
        let key = currentSlot.content.key
        Task { [weak self] in
            guard let content = await fetchNeighbor(key, forward) else { return }
            guard let self,
                  self.currentSlot?.content.key == key,
                  (forward ? self.nextSlot : self.previousSlot) == nil else { return }
            let slot = self.makeSlot(content)
            if forward { self.nextSlot = slot } else { self.previousSlot = slot }
        }
    }

    private func slot(for key: ChapterKey) -> Slot? {
        if currentSlot?.content.key == key { return currentSlot }
        if nextSlot?.content.key == key { return nextSlot }
        if previousSlot?.content.key == key { return previousSlot }
        return nil
    }

    private func pageCount(_ key: ChapterKey) -> Int {
        slot(for: key)?.paginator?.pageCount ?? 0
    }

    private func slotKey(after key: ChapterKey) -> ChapterKey? {
        if key == previousSlot?.content.key { return currentSlot?.content.key }
        if key == currentSlot?.content.key { return nextSlot?.content.key }
        return nil
    }

    private func slotKey(before key: ChapterKey) -> ChapterKey? {
        if key == nextSlot?.content.key { return currentSlot?.content.key }
        if key == currentSlot?.content.key { return previousSlot?.content.key }
        return nil
    }

    private func isFiller(_ ref: PageRef) -> Bool {
        ref.index >= pageCount(ref.key)
    }

    /// Pages a chapter occupies in the flip sequence: padded to an even count in a spread
    /// so the next chapter always opens on a fresh left-hand page.
    private func sequenceLength(_ key: ChapterKey) -> Int {
        let count = pageCount(key)
        return isSpread ? count + count % 2 : count
    }

    private func side(of ref: PageRef) -> PageSide {
        guard isSpread else { return .single }
        return ref.index % 2 == 0 ? .left : .right
    }

    // MARK: - Page order

    /// After a chapter's last page (or its filler) comes the next chapter's first page
    /// once that chapter is loaded; until then the flip simply isn't offered.
    private func nextRef(after ref: PageRef) -> PageRef? {
        if ref.index + 1 < sequenceLength(ref.key) { return PageRef(key: ref.key, index: ref.index + 1) }
        if let nextKey = slotKey(after: ref.key), pageCount(nextKey) > 0 { return PageRef(key: nextKey, index: 0) }
        return nil
    }

    private func previousRef(before ref: PageRef) -> PageRef? {
        if ref.index > 0 { return PageRef(key: ref.key, index: ref.index - 1) }
        if let prevKey = slotKey(before: ref.key), pageCount(prevKey) > 0 {
            return PageRef(key: prevKey, index: sequenceLength(prevKey) - 1)
        }
        return nil
    }

    private func makePage(_ ref: PageRef) -> PageViewController {
        let pageSide = side(of: ref)
        let count = pageCount(ref.key)
        let paginator = isFiller(ref) ? nil : slot(for: ref.key)?.paginator
        let isCurrentChapter = ref.key == currentSlot?.content.key
        var insets = textInsets
        // The gutter sits on the spine side so the outer margins stay at their usual width.
        switch pageSide {
        case .left: insets.right += layout?.spineGutter ?? 0
        case .right: insets.left += layout?.spineGutter ?? 0
        case .single: break
        }
        let page = PageViewController(
            ref: ref,
            side: pageSide,
            paginator: paginator,
            textInsets: insets,
            footerText: paginator == nil ? "" : "\(ref.index + 1) / \(count)",
            style: style,
            // Stripes/selection/highlights describe the view model's chapter only.
            bookmarkStripes: isCurrentChapter ? bookmarkStripes : [:],
            highlights: isCurrentChapter ? highlights : PageHighlights()
        )
        if isCurrentChapter {
            page.onVerseTapped = { [weak self] verse in self?.onVerseTapped?(verse) }
            page.contextMenu = { [weak self] verse in self?.contextMenu?(verse) }
        }
        return page
    }

    // MARK: - Display

    private var displayedPages: [PageViewController] {
        pageViewController?.viewControllers?.compactMap { $0 as? PageViewController } ?? []
    }

    private var displayedRefs: [PageRef] { displayedPages.map(\.ref) }

    private func currentFirstVisibleVerse() -> Int? {
        for ref in displayedRefs where !isFiller(ref) {
            if let verse = slot(for: ref.key)?.paginator?.firstVerse(onPage: ref.index) { return verse }
        }
        return nil
    }

    private func display(pageContaining verse: Int, animated: Bool) {
        guard let currentSlot, let paginator = currentSlot.paginator else { return }
        let index = paginator.pageIndex(containingVerse: verse) ?? 0
        display(PageRef(key: currentSlot.content.key, index: index), direction: .forward, animated: animated)
    }

    /// Shows the spread (or page) that contains `ref`: in a spread the left page is the
    /// even index at or before `ref`, so a verse on an even-numbered page shows on the
    /// right with its preceding page on the left, never forced to the left.
    private func display(_ ref: PageRef, direction: UIPageViewController.NavigationDirection, animated: Bool) {
        guard let pageViewController, !isTransitioning else { return }
        guard isSpread else {
            pageViewController.setViewControllers([makePage(ref)], direction: direction, animated: animated)
            return
        }
        let left = PageRef(key: ref.key, index: ref.index - ref.index % 2)
        let right = nextRef(after: left) ?? PageRef(key: left.key, index: left.index + 1)
        pageViewController.setViewControllers([makePage(left), makePage(right)], direction: direction, animated: animated)
    }

    /// Turns to the page of the verse being read aloud when it isn't on screen.
    private func followTTS() {
        guard let index = highlights.ttsVerseIndex,
              let currentSlot,
              let page = currentSlot.paginator?.pageIndex(containingVerse: index + 1) else { return }
        let ref = PageRef(key: currentSlot.content.key, index: page)
        guard !displayedRefs.contains(ref) else { return }
        display(ref, direction: .forward, animated: true)
    }

    private func redrawDisplayedPages() {
        for page in displayedPages where page.ref.key == currentSlot?.content.key {
            page.update(bookmarkStripes: bookmarkStripes, highlights: highlights)
        }
    }

    private func reportDisplayedPosition() {
        guard let ref = displayedRefs.first(where: { !isFiller($0) }),
              let verse = slot(for: ref.key)?.paginator?.firstVerse(onPage: ref.index) else { return }
        onPageChanged?(ref.key, verse)
    }
}

// MARK: - UIPageViewControllerDataSource / Delegate

extension PagedReaderController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PageViewController, let ref = previousRef(before: page.ref) else { return nil }
        return makePage(ref)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PageViewController, let ref = nextRef(after: page.ref) else { return nil }
        return makePage(ref)
    }

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        isTransitioning = true
        onUserInteraction?()
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        isTransitioning = false
        onUserInteraction?()
        // Any page replacement waits for the next run-loop turn: changing the page view
        // controller's pages from inside its own completion callback stalls it, which
        // showed up as the reader freezing after a burst of fast flips.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let verse = self.pendingLandingVerse, !self.isTransitioning {
                self.pendingLandingVerse = nil
                self.display(pageContaining: verse, animated: false)
            }
            if completed { self.reportDisplayedPosition() }
        }
    }
}

// MARK: - Page

/// One opaque page: the typeset text for its container plus a small "n / total" footer.
/// A filler (no paginator) is a blank sheet of the same paper color.
final class PageViewController: UIViewController {
    /// Margins around the text area beyond the safe area; the bottom one also holds the footer.
    static let textInsets = UIEdgeInsets(top: 12, left: 24, bottom: 32, right: 24)

    let ref: PageRef
    let side: PageSide
    private let textView: PageTextView?
    private let textInsets: UIEdgeInsets
    private let footer = UILabel()

    var onVerseTapped: ((Int) -> Void)? {
        didSet { textView?.onVerseTapped = onVerseTapped }
    }
    var contextMenu: ((Int) -> UIMenu?)? {
        didSet { textView?.contextMenu = contextMenu }
    }
    var verseTapRecognizer: UITapGestureRecognizer? { textView?.tapRecognizer }

    init(
        ref: PageRef,
        side: PageSide,
        paginator: ChapterPaginator?,
        textInsets: UIEdgeInsets,
        footerText: String,
        style: PageTextStyle?,
        bookmarkStripes: [Int: [BookmarkStripe?]],
        highlights: PageHighlights
    ) {
        self.ref = ref
        self.side = side
        self.textInsets = textInsets
        self.textView = paginator.map {
            PageTextView(paginator: $0, pageIndex: ref.index, textOriginX: textInsets.left, bookmarkStripes: bookmarkStripes, highlights: highlights)
        }
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = style?.backgroundColor ?? .systemBackground
        textView?.pageBackgroundColor = style?.backgroundColor ?? .systemBackground
        footer.text = footerText
        footer.textColor = style?.verseNumberColor ?? .secondaryLabel
        footer.font = .systemFont(ofSize: 12)
        footer.textAlignment = .center
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let textView { view.addSubview(textView) }
        view.addSubview(footer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let insets = textInsets
        // The text view spans the page's full width (the stripe gutter lives left of the
        // text) and is offset inside by `textOriginX`.
        textView?.frame = CGRect(x: 0, y: insets.top, width: view.bounds.width, height: view.bounds.height - insets.top - insets.bottom)
        footer.frame = CGRect(
            x: insets.left,
            y: view.bounds.height - insets.bottom + 8,
            width: view.bounds.width - insets.left - insets.right,
            height: 16
        )
    }

    func update(bookmarkStripes: [Int: [BookmarkStripe?]], highlights: PageHighlights) {
        textView?.bookmarkStripes = bookmarkStripes
        textView?.highlights = highlights
        textView?.setNeedsDisplay()
    }
}

/// Draws one text container of a `ChapterPaginator` straight through its layout manager,
/// with highlight bands behind the verses and the bookmark stripes in the left gutter,
/// and hosts the verse tap and long-press menu. A plain view (not `UITextView`) so
/// several pages can share the one layout manager without UIKit fighting over container
/// ownership.
final class PageTextView: UIView {
    /// How far a highlight band reaches beyond the verse's glyphs, like the scroll
    /// reader's padded row.
    private static let bandPadding = CGSize(width: 8, height: 6)

    private let paginator: ChapterPaginator
    private let pageIndex: Int
    private let textOriginX: CGFloat
    var bookmarkStripes: [Int: [BookmarkStripe?]]
    var highlights: PageHighlights
    var pageBackgroundColor: UIColor = .systemBackground
    var onVerseTapped: ((Int) -> Void)?
    var contextMenu: ((Int) -> UIMenu?)?
    private(set) var tapRecognizer: UITapGestureRecognizer!

    init(paginator: ChapterPaginator, pageIndex: Int, textOriginX: CGFloat, bookmarkStripes: [Int: [BookmarkStripe?]], highlights: PageHighlights) {
        self.paginator = paginator
        self.pageIndex = pageIndex
        self.textOriginX = textOriginX
        self.bookmarkStripes = bookmarkStripes
        self.highlights = highlights
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        // Theme colors are dynamic; redraw when light/dark flips.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
            view.setNeedsDisplay()
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        tapRecognizer = tap
        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func verse(at point: CGPoint) -> Int? {
        paginator.verse(at: CGPoint(x: point.x - textOriginX, y: point.y), onPage: pageIndex)
    }

    private func rect(forVerse verse: Int) -> CGRect? {
        paginator.rect(forVerse: verse, onPage: pageIndex)?.offsetBy(dx: textOriginX, dy: 0)
    }

    /// The band behind a run of verses: the full column width (number through text),
    /// padded, covering just the part of the run that is on this page — so a verse split
    /// over a page break gets a clean rectangle on each page, and a multi-verse selection
    /// is one unbroken block.
    private func band(forVerses verses: ClosedRange<Int>) -> CGRect? {
        let rects = verses.compactMap { rect(forVerse: $0) }
        guard let first = rects.first else { return nil }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        let padding = Self.bandPadding
        return CGRect(
            x: textOriginX - padding.width,
            y: union.minY - padding.height,
            width: paginator.pageSize.width + padding.width * 2,
            height: union.height + padding.height * 2
        )
    }

    /// The verse tap only begins over verse text, so a tap in the margins or below the
    /// last line fails and the page curl's own edge tap can turn the page.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === tapRecognizer else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        // Neighbour-chapter pages have no tap handler: let the page curl take every tap.
        guard onVerseTapped != nil else { return false }
        return verse(at: gestureRecognizer.location(in: self)) != nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let verse = verse(at: recognizer.location(in: self)) else { return }
        onVerseTapped?(verse)
    }

    override func draw(_ rect: CGRect) {
        guard let container = paginator.container(at: pageIndex) else { return }
        drawHighlights()
        let origin = CGPoint(x: textOriginX, y: 0)
        let glyphRange = paginator.layoutManager.glyphRange(for: container)
        paginator.layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
        drawStripes()
    }

    /// Same colors as the scroll reader: orange for a navigated verse, green for the
    /// verse being read aloud, accent for the selection (drawn last, so it wins).
    private func drawHighlights() {
        var bands: [(ClosedRange<Int>, UIColor)] = []
        if let verse = highlights.navigatedVerse { bands.append((verse...verse, UIColor.orange.withAlphaComponent(0.25))) }
        if let index = highlights.ttsVerseIndex { bands.append((index + 1...index + 1, UIColor.green.withAlphaComponent(0.2))) }
        if let selected = highlights.selectedVerses { bands.append((selected, UIColor.tintColor.withAlphaComponent(0.25))) }
        for (verses, color) in bands {
            guard let band = band(forVerses: verses) else { continue }
            color.setFill()
            UIRectFill(band)
        }
    }

    /// Same geometry as the scroll reader's `stripeView`: 3pt columns 1pt apart at the
    /// leading edge, bridging the verse gap when a bookmark continues up/down.
    private func drawStripes() {
        guard !bookmarkStripes.isEmpty else { return }
        let halfGap = paginator.verseGap / 2
        for verse in paginator.verses(onPage: pageIndex) {
            guard let stripes = bookmarkStripes[verse], let verseRect = rect(forVerse: verse) else { continue }
            for (column, stripe) in stripes.prefix(BookmarkStripeComputer.columnLimit).enumerated() {
                guard let stripe else { continue }
                let top = verseRect.minY - (stripe.extendsUp ? halfGap : 0)
                let bottom = verseRect.maxY + (stripe.extendsDown ? halfGap : 0)
                let x = 8 + CGFloat(column) * 4
                UIColor(stripe.color.swiftUIColor).withAlphaComponent(0.8).setFill()
                UIRectFill(CGRect(x: x, y: top, width: 3, height: bottom - top))
            }
        }
    }
}

extension PageTextView: UIGestureRecognizerDelegate {
    /// The page curl's own tap (edge tap turns the page) waits for the verse tap, so a
    /// tap on verse text selects instead of flipping. Declared per touch rather than with
    /// `require(toFail:)`, which would pile up a requirement per page ever created.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === tapRecognizer && otherGestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer.view !== self
    }
}

extension PageTextView: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let contextMenu, let verse = verse(at: location), let menu = contextMenu(verse) else { return nil }
        return UIContextMenuConfiguration(identifier: NSNumber(value: verse), previewProvider: nil) { _ in menu }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }

    /// Lifts just the pressed verse (its band) out of the page, on paper color.
    private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let verse = (configuration.identifier as? NSNumber)?.intValue, let band = band(forVerses: verse...verse) else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = pageBackgroundColor
        parameters.visiblePath = UIBezierPath(roundedRect: band, cornerRadius: 10)
        return UITargetedPreview(view: self, parameters: parameters)
    }
}
