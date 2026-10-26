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
/// - A crease running left-to-right (half-folded in portrait) can't be a spine and is
///   ignored: text runs straight across it, like the scroll reader (user decision).
/// - Without a crease, landscape (wider than tall) is a spread, portrait a single page.
///   A spread spans the area between the side safe areas (`sideInsets`) so both pages
///   are the same width whichever side the Dynamic Island or a toolbar column is on.
struct PagedReaderLayout: Equatable {
    var pageAreaFrame: CGRect
    var isSpread: Bool
    /// The spread is pinned to a fold crease (half-folded device) rather than laid out freely.
    var isCreaseCentred = false
    /// Extra inset on a page's spine side so text clears the crease (0 without a spine
    /// crease). Half the crease, less `spineMarginTrim`: next to the spine the page gives
    /// up part of its base margin, so the text sits `textInsets.left - spineMarginTrim`
    /// from the crease edge instead of a full margin and the two halves read closer.
    var spineGutter: CGFloat = 0
    /// How much of the base side margin a half-folded page spends on the spine side
    /// (leaving 12pt next to the crease).
    static let spineMarginTrim: CGFloat = 4
    /// Likewise on the outer edge: a half-folded page is narrow, so it keeps a tighter
    /// frame there too (`textInsets.left - outerMarginTrim` plus the side safe area).
    static let outerMarginTrim: CGFloat = 4
    /// `spreadEnabled` false (the Labs "Two-Page Spread" toggle) keeps a single page
    /// whatever the orientation; a vertical crease then runs through the page like a
    /// horizontal one does.
    static func resolve(
        bounds: CGRect, divisionRegions: [CGRect], sideInsets: (left: CGFloat, right: CGFloat) = (0, 0), spreadEnabled: Bool = true
    ) -> PagedReaderLayout {
        guard spreadEnabled else { return PagedReaderLayout(pageAreaFrame: bounds, isSpread: false) }
        let regions = divisionRegions.filter { !$0.isEmpty && $0.intersects(bounds) }
        if let crease = regions.first(where: { $0.height > $0.width }) {
            let center = crease.midX
            let half = min(center - bounds.minX, bounds.maxX - center)
            // A crease near an edge can't carry a readable spread; ignore it.
            guard half >= 160 else { return fallback(bounds, sideInsets: sideInsets) }
            return PagedReaderLayout(
                pageAreaFrame: CGRect(x: center - half, y: bounds.minY, width: half * 2, height: bounds.height),
                isSpread: true,
                isCreaseCentred: true,
                spineGutter: max(0, ceil(crease.width / 2) - spineMarginTrim)
            )
        }
        return fallback(bounds, sideInsets: sideInsets)
    }

    private static func fallback(_ bounds: CGRect, sideInsets: (left: CGFloat, right: CGFloat)) -> PagedReaderLayout {
        let isSpread = bounds.width > bounds.height
        var area = bounds
        if isSpread, bounds.width - sideInsets.left - sideInsets.right >= 320 {
            area.origin.x += sideInsets.left
            area.size.width -= sideInsets.left + sideInsets.right
        }
        return PagedReaderLayout(pageAreaFrame: area, isSpread: isSpread)
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
    /// Fired when the left edge of the text column (window coordinates) moves, so the
    /// toolbar title can line up with the verses instead of the bar's own margin.
    var onTextLeadingChanged: ((CGFloat) -> Void)?
    /// The tab bar pill that covers part of the page (a foldable's trailing column), in
    /// window coordinates, so floating chrome can keep clear of it; nil when none does.
    var onTabBarOcclusionChanged: ((CGRect?) -> Void)?
    private var reportedTabBarOcclusion: CGRect?
    /// Two pages side by side in landscape (the Labs toggle); off keeps one page always.
    var isSpreadEnabled = true {
        didSet { if isSpreadEnabled != oldValue { view.setNeedsLayout() } }
    }
    private var reportedTextLeadingX: CGFloat?

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
    /// The old pages, kept on top while a fold, unfold or rotation opens the new ones.
    private var relayoutSnapshot: UIView?
    private var relayoutAnimationsInFlight = 0
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
    /// A tab bar that is not a bottom strip (a vertical pill at the trailing edge on a
    /// foldable), in view coordinates. Text flows around it on the pages it covers
    /// instead of giving up the whole bottom of every page.
    private var tabBarOcclusion: CGRect?
    /// Stands in for the device's fold creases (unit tests only; no foldable simulator).
    var divisionRegionsForTesting: [CGRect]? {
        didSet { view.setNeedsLayout() }
    }
    /// Stands in for system UI occlusion regions (a foldable's trailing tab column).
    var occlusionRegionsForTesting: [CGRect]? {
        didSet { view.setNeedsLayout() }
    }

    /// Margins around a page's text, before the spine gutter and the outer safe inset.
    /// A single page keeps the side safe areas (the Dynamic Island in landscape) out of
    /// both margins; a spread handles them through `outerInset` instead. The user's
    /// extra side margin widens both sides of every page.
    private var textInsets: UIEdgeInsets {
        let base = PageViewController.textInsets
        let extra = style?.sideMargin ?? 0
        return UIEdgeInsets(
            top: base.top + contentInsets.top,
            left: base.left + extra + (isSpread ? 0 : contentInsets.left),
            bottom: base.bottom + max(contentInsets.bottom, tabBarReserve),
            right: base.right + extra + (isSpread ? 0 : contentInsets.right)
        )
    }

    /// Adjustment to each spread page's outer-edge margin; the spine side never gets it.
    /// A plain spread already sits between the side safe areas (`sideInsets` in the
    /// layout), so only a crease-centred spread needs them: it is pinned to the crease,
    /// and both halves keep the same margin (the larger side) so the book stays
    /// symmetric. Less `outerMarginTrim`, so the half-folded frame is a little tighter;
    /// negative when there is no safe area at all (the base margin shrinks).
    private var outerInset: CGFloat {
        guard let layout, layout.isCreaseCentred else { return 0 }
        return max(contentInsets.left, contentInsets.right) - PagedReaderLayout.outerMarginTrim
    }

    /// Tallest strip a bottom tab bar can plausibly take; anything else found in the
    /// window (a hidden/top-anchored bar) is ignored rather than blanking the pages.
    private static let maxTabBarReserve: CGFloat = 120

    /// Where the visible tab bar sits over this view. The bar's own frame is not trusted
    /// (it can be a strip, or the whole window, depending on the OS); its visible content
    /// views are measured instead. A wide band along the bottom becomes a bottom reserve;
    /// anything else (a trailing-edge pill) becomes an occlusion rect.
    private func measureTabBar() -> (reserve: CGFloat, occlusion: CGRect?) {
        guard let window = view.window else { return (0, nil) }
        var reserve: CGFloat = 0
        var occlusion: CGRect?
        for bar in Self.tabBars(in: window) where !bar.isHidden && bar.alpha > 0 {
            let contentFrames = bar.subviews
                .filter { !$0.isHidden && $0.alpha > 0 && !$0.bounds.isEmpty }
                .map { $0.convert($0.bounds, to: view) }
            let frame = contentFrames.dropFirst().reduce(contentFrames.first ?? bar.convert(bar.bounds, to: view)) { $0.union($1) }
            guard frame.intersects(view.bounds) else { continue }
            let isBottomStrip = frame.minY >= view.bounds.maxY - Self.maxTabBarReserve && frame.width >= view.bounds.width / 2
            if isBottomStrip {
                reserve = max(reserve, view.bounds.maxY - frame.minY)
            } else {
                occlusion = occlusion.map { $0.union(frame) } ?? frame
            }
        }
        // System chrome the window hierarchy doesn't show as a tab bar (a foldable's
        // trailing tab column) is reported by UIKit as an occlusion region instead.
        for frame in occlusionRegionFrames() where frame.intersects(view.bounds) {
            occlusion = occlusion.map { $0.union(frame) } ?? frame
        }
        return (reserve, occlusion)
    }

    /// Active regions system UI covers, in the view's coordinates (iOS 27.1+), margins
    /// included so text and floating chrome keep a little clear of them.
    private func occlusionRegionFrames() -> [CGRect] {
        if let occlusionRegionsForTesting { return occlusionRegionsForTesting }
        if #available(iOS 27.1, *) {
            return view.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
        }
        return []
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
            width: pageSize.width - insets.left - insets.right - (layout?.spineGutter ?? 0) - outerInset,
            height: pageSize.height - insets.top - insets.bottom
        )
        if size.width < 120 { size.width = pageSize.width - base.left - base.right }
        if size.height < 120 { size.height = pageSize.height - base.top - base.bottom }
        return size
    }

    /// Areas text must flow around on the page at `index`, in page text coordinates: the
    /// tab bar pill, only on the page it actually covers.
    private func exclusionRects(forPage index: Int) -> [CGRect] {
        var rects: [CGRect] = []
        let insets = textInsets
        let pageSide = side(of: PageRef(key: ChapterKey(versionCode: "", bookCode: "", chapter: 0), index: index))
        if let occlusion = tabBarOcclusion, let layout {
            var pageFrame = layout.pageAreaFrame
            pageFrame.size = pageSize
            if pageSide == .right { pageFrame.origin.x += pageSize.width }
            let textOriginX = insets.left + (pageSide == .right ? layout.spineGutter : outerInset)
            let textFrame = CGRect(origin: CGPoint(x: pageFrame.minX + textOriginX, y: pageFrame.minY + insets.top), size: textSize)
            let padded = occlusion.insetBy(dx: -12, dy: -12)
            if padded.intersects(textFrame) {
                rects.append(padded.offsetBy(dx: -textFrame.minX, dy: -textFrame.minY))
            }
        }
        return rects
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
        // The side margin moves the verse column without a layout pass; tell the toolbar now.
        if styleChanged { reportTextLeadingIfNeeded() }
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
        let newLayout = PagedReaderLayout.resolve(
            bounds: bounds,
            divisionRegions: divisionRegionFrames(),
            sideInsets: (contentInsets.left, contentInsets.right),
            spreadEnabled: isSpreadEnabled
        )
        let tabBar = measureTabBar()
        // Cheap and idempotent; also catches the view being moved into its window after
        // the first layout, which changes window coordinates without changing the layout.
        defer {
            reportTextLeadingIfNeeded()
            reportTabBarOcclusionIfNeeded(tabBar.occlusion)
        }
        guard newLayout != layout || pageViewController == nil || paginatedInsets != contentInsets
                || tabBar.reserve != tabBarReserve || tabBar.occlusion != tabBarOcclusion else { return }

        let landingVerse = pendingLandingVerse ?? currentFirstVisibleVerse()
        pendingLandingVerse = nil
        let spreadChanged = newLayout.isSpread != layout?.isSpread
        let previousLayout = layout
        let isRelayout = previousLayout != nil && previousLayout != newLayout
        let oldPages = isRelayout ? pageViewController?.view.snapshotView(afterScreenUpdates: false) : nil
        layout = newLayout
        paginatedInsets = contentInsets
        tabBarReserve = tabBar.reserve
        tabBarOcclusion = tabBar.occlusion
        // This often runs inside UIKit's size-transition animation, which would animate
        // every new frame from zero (pages sliding in from the top-left corner). The new
        // pages are laid out in place; `animateRelayout` supplies the motion instead.
        UIView.performWithoutAnimation {
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
            pageViewController?.view.layoutIfNeeded()
        }
        if isRelayout, let previousLayout {
            animateRelayout(from: oldPages, oldFrame: previousLayout.pageAreaFrame)
        }
    }

    /// A fold, unfold or rotation re-typesets everything, so the old pages can't morph
    /// into the new ones. The new spread opens from its centre (the spine) while the old
    /// pages fade out, widening the same way, so the book reads as opening further.
    private func animateRelayout(from snapshot: UIView?, oldFrame: CGRect) {
        guard let pageView = pageViewController?.view, view.window != nil else { return }
        relayoutSnapshot?.removeFromSuperview()
        relayoutSnapshot = snapshot
        UIView.performWithoutAnimation {
            if let snapshot {
                // Centred on the new spine so the old pages dissolve where the new ones
                // open; no autoresizing, or the rotating bounds would stretch them.
                snapshot.autoresizingMask = []
                snapshot.bounds = CGRect(origin: .zero, size: oldFrame.size)
                snapshot.center = CGPoint(x: pageView.frame.midX, y: pageView.frame.midY)
                view.addSubview(snapshot)
            }
            pageView.transform = CGAffineTransform(scaleX: 0.85, y: 1)
            pageView.alpha = 0
        }
        relayoutAnimationsInFlight += 1
        UIView.animate(
            withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
            options: [.overrideInheritedDuration, .overrideInheritedCurve, .overrideInheritedOptions, .allowUserInteraction]
        ) {
            pageView.transform = .identity
            pageView.alpha = 1
            snapshot?.transform = CGAffineTransform(scaleX: 1.1, y: 1)
            snapshot?.alpha = 0
        } completion: { [weak self, weak snapshot] _ in
            snapshot?.removeFromSuperview()
            guard let self else { return }
            relayoutAnimationsInFlight -= 1
            if relayoutSnapshot === snapshot { relayoutSnapshot = nil }
        }
    }

    /// Whether a relayout animation is still running (tests).
    var isAnimatingRelayout: Bool { relayoutAnimationsInFlight > 0 }

    /// Where the first (or only) page's verse numbers start, in window coordinates.
    var textLeadingX: CGFloat {
        guard let layout else { return 0 }
        let x = layout.pageAreaFrame.minX + textInsets.left + outerInset
        return view.convert(CGPoint(x: x, y: 0), to: nil).x
    }

    private func reportTabBarOcclusionIfNeeded(_ occlusion: CGRect?) {
        let inWindow = occlusion.map { view.convert($0, to: nil) }
        guard inWindow != reportedTabBarOcclusion else { return }
        reportedTabBarOcclusion = inWindow
        onTabBarOcclusionChanged?(inWindow)
    }

    private func reportTextLeadingIfNeeded() {
        let x = textLeadingX
        guard x != reportedTextLeadingX else { return }
        reportedTextLeadingX = x
        onTextLeadingChanged?(x)
    }

    /// Active fold creases in the view's coordinates (foldable iPhone, iOS 27.1+). The
    /// physical crease only: the region's frame also carries recommended margins, which
    /// would double the gutter on a half-folded device.
    private func divisionRegionFrames() -> [CGRect] {
        if let divisionRegionsForTesting { return divisionRegionsForTesting }
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
        // In a spread the comparison text takes the facing page (parallel layout).
        slot.paginator = ChapterPaginator(content: slot.content, style: style, pageSize: textSize, parallel: isSpread) { [self] index in
            exclusionRects(forPage: index)
        }
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
        // The gutter sits on the spine side, the safe-area inset (if any) on the outer side.
        switch pageSide {
        case .left:
            insets.left += outerInset
            insets.right += layout?.spineGutter ?? 0
        case .right:
            insets.left += layout?.spineGutter ?? 0
            insets.right += outerInset
        case .single: break
        }
        let page = PageViewController(
            ref: ref,
            side: pageSide,
            paginator: paginator,
            textInsets: insets,
            footerText: paginator.map { $0.isParallel ? "\(ref.index / 2 + 1) / \(count / 2)" : "\(ref.index + 1) / \(count)" } ?? "",
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
        // The pages being replaced may have a verse menu open; close it with them on screen.
        displayedPages.forEach { $0.dismissVerseMenu() }
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
            // A page built as a prefetched neighbour had no handlers (its taps turned the
            // page); once its chapter is current, verse taps must select on it too.
            if page.onVerseTapped == nil {
                page.onVerseTapped = { [weak self] verse in self?.onVerseTapped?(verse) }
                page.contextMenu = { [weak self] verse in self?.contextMenu?(verse) }
            }
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
    /// Side margins match the scroll reader's verse rows (8pt row padding + 8pt inner
    /// padding), so switching modes keeps the verse column in the same place.
    static let textInsets = UIEdgeInsets(top: 24, left: 16, bottom: 32, right: 16)

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
    /// The text container this page typesets into (nil for a filler).
    var textContainer: NSTextContainer? { textView?.textContainer }

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
            PageTextView(paginator: $0, pageIndex: ref.index, textOriginX: textInsets.left, bandInset: PageTextView.bandPadding.width + (style?.sideMargin ?? 0), stripesOnTrailingEdge: side == .right, bookmarkStripes: bookmarkStripes, highlights: highlights)
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
        // text) and is offset inside by `textOriginX`. It also reaches a band's height
        // above and below the text, so the first and last verses' bands are not clipped.
        let reach = PageTextView.textOriginY
        textView?.frame = CGRect(x: 0, y: insets.top - reach, width: view.bounds.width, height: view.bounds.height - insets.top - insets.bottom + reach * 2)
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

    func dismissVerseMenu() {
        textView?.interactions.compactMap { $0 as? UIContextMenuInteraction }.forEach { $0.dismissMenu() }
    }
}

/// Draws one text container of a `ChapterPaginator` straight through its layout manager,
/// with highlight bands behind the verses and the bookmark stripes in the left gutter,
/// and hosts the verse tap and long-press menu. A plain view (not `UITextView`) so
/// several pages can share the one layout manager without UIKit fighting over container
/// ownership.
final class PageTextView: UIView {
    /// How far a highlight band reaches beyond the verse's glyphs, like the scroll
    /// reader's padded row: sideways through the whole margin (edge to edge on a single
    /// page), the row's 8pt padding above and below (so neighbouring bands are the line
    /// spacing apart, as in the scroll reader).
    static let bandPadding = CGSize(width: 16, height: 8)
    /// Where the text starts inside the view: one band padding down, leaving room for
    /// the top verse's band above its glyphs.
    static let textOriginY = bandPadding.height
    /// Sideways reach of the band and stripe edge: the base padding plus the user's
    /// extra side margin, so a selection covers the margin like the scroll reader's row.
    let bandInset: CGFloat

    private let paginator: ChapterPaginator
    private let pageIndex: Int
    let textOriginX: CGFloat
    /// The right page of a spread keeps its stripes on the outer (right) edge, mirroring
    /// the left page, so the spine stays clear.
    let stripesOnTrailingEdge: Bool
    var textContainer: NSTextContainer? { paginator.container(at: pageIndex) }
    var bookmarkStripes: [Int: [BookmarkStripe?]]
    var highlights: PageHighlights
    var pageBackgroundColor: UIColor = .systemBackground
    var onVerseTapped: ((Int) -> Void)?
    var contextMenu: ((Int) -> UIMenu?)?
    private(set) var tapRecognizer: UITapGestureRecognizer!

    init(paginator: ChapterPaginator, pageIndex: Int, textOriginX: CGFloat, bandInset: CGFloat = PageTextView.bandPadding.width, stripesOnTrailingEdge: Bool = false, bookmarkStripes: [Int: [BookmarkStripe?]], highlights: PageHighlights) {
        self.paginator = paginator
        self.pageIndex = pageIndex
        self.textOriginX = textOriginX
        self.bandInset = bandInset
        self.stripesOnTrailingEdge = stripesOnTrailingEdge
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
        paginator.verse(at: CGPoint(x: point.x - textOriginX, y: point.y - Self.textOriginY), onPage: pageIndex)
    }

    func rect(forVerse verse: Int) -> CGRect? {
        paginator.rect(forVerse: verse, onPage: pageIndex)?.offsetBy(dx: textOriginX, dy: Self.textOriginY)
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
            x: textOriginX - bandInset,
            y: union.minY - padding.height,
            width: paginator.pageSize.width + bandInset * 2,
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
        guard let container = paginator.container(at: pageIndex), let layoutManager = paginator.layoutManager(forPage: pageIndex) else { return }
        drawHighlights()
        let origin = CGPoint(x: textOriginX, y: Self.textOriginY)
        let glyphRange = layoutManager.glyphRange(for: container)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
        drawStripes()
    }

    /// Same colors and stacking as the scroll reader's row backgrounds: the selection
    /// underneath, the verse being read aloud over it, a navigated verse on top.
    private func drawHighlights() {
        var bands: [(ClosedRange<Int>, UIColor)] = []
        if let selected = highlights.selectedVerses { bands.append((selected, UIColor.tintColor.withAlphaComponent(0.25))) }
        if let index = highlights.ttsVerseIndex { bands.append((index + 1...index + 1, UIColor.green.withAlphaComponent(0.2))) }
        if let verse = highlights.navigatedVerse { bands.append((verse...verse, UIColor.orange.withAlphaComponent(0.25))) }
        for (verses, color) in bands {
            guard let band = band(forVerses: verses) else { continue }
            color.setFill()
            UIRectFill(band)
        }
    }

    /// Same geometry as the scroll reader's `stripeView`: 3pt columns 1pt apart at the
    /// outer edge of the margin (column 0 outermost), bridging the verse gap when a
    /// bookmark continues up/down.
    private func drawStripes() {
        guard !bookmarkStripes.isEmpty else { return }
        let halfGap = paginator.verseGap / 2
        let leadingEdge = textOriginX - bandInset
        let trailingEdge = textOriginX + paginator.pageSize.width + bandInset
        for verse in paginator.verses(onPage: pageIndex) {
            guard let stripes = bookmarkStripes[verse], let verseRect = rect(forVerse: verse) else { continue }
            for (column, stripe) in stripes.prefix(BookmarkStripeComputer.columnLimit).enumerated() {
                guard let stripe else { continue }
                let top = verseRect.minY - (stripe.extendsUp ? halfGap : 0)
                let bottom = verseRect.maxY + (stripe.extendsDown ? halfGap : 0)
                let x = stripesOnTrailingEdge
                    ? trailingEdge - 3 - CGFloat(column) * 4
                    : leadingEdge + CGFloat(column) * 4
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
        targetedPreview(for: configuration, tinted: true)
    }

    /// The dismissal copy matches the page exactly (no tint), so UIKit lingering with it
    /// over the page after the menu closes is invisible, as in the scroll reader.
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        targetedPreview(for: configuration, tinted: false)
    }

    /// Lifts just the pressed verse (its band) out of the page, on paper color.
    ///
    /// The lifted view is a rendered copy of the band, not this view: UIKit hides the
    /// preview's view while the menu is up, so lifting the page itself (clipped to the
    /// band) made every other verse on the page vanish.
    private func targetedPreview(for configuration: UIContextMenuConfiguration, tinted: Bool) -> UITargetedPreview? {
        // A relayout (rotation, fold) replaces the pages while a menu is up; UIKit still
        // asks this page for the dismissal preview, and a target outside a window throws.
        guard window != nil, let verse = (configuration.identifier as? NSNumber)?.intValue else { return nil }
        // Pressing inside the selection lifts the whole selection, like the scroll reader's preview.
        let verses = highlights.selectedVerses.flatMap { $0.contains(verse) ? $0 : nil } ?? verse...verse
        guard let band = band(forVerses: verses) else { return nil }
        let image = UIGraphicsImageRenderer(bounds: band).image { context in
            pageBackgroundColor.setFill()
            context.fill(band)
            layer.render(in: context.cgContext)
            // The scroll reader's preview always tints its verses as selected; a page
            // only has the tint drawn when the verses are actually selected.
            // Over the text, so not the default copy blend (which would replace the glyphs).
            if tinted, highlights.selectedVerses?.contains(verse) != true {
                tintColor.withAlphaComponent(0.25).setFill()
                context.fill(band, blendMode: .normal)
            }
        }
        let copy = UIImageView(image: image)
        copy.frame = band
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = pageBackgroundColor
        parameters.visiblePath = UIBezierPath(roundedRect: copy.bounds, cornerRadius: 10)
        let target = UIPreviewTarget(container: self, center: CGPoint(x: band.midX, y: band.midY))
        return UITargetedPreview(view: copy, parameters: parameters, target: target)
    }
}
