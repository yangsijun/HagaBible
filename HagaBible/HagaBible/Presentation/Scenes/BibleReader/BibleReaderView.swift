//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

private struct AddBookmarkRequest: Identifiable, Equatable {
    let id = UUID()
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let startVerse: Int
    let endVerse: Int
}

/// A pending copy/share that needs the user to pick which version(s) to export
/// (shown only while translation comparison is on).
private struct VerseExportRequest: Identifiable {
    enum Mode { case copy, share }
    let id = UUID()
    let startIndex: Int
    let endIndex: Int
    let mode: Mode
}

/// Wrapper so the resolved share text can drive a `.sheet(item:)`.
private struct ShareTextItem: Identifiable {
    let id = UUID()
    let text: String
}

struct BibleReaderView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState = DIContainer.shared.resolve(type: AppState.self)
    /// Per-window (`RootView` provides them): this window's reader and its tab/Library routing.
    @Environment(BibleReaderViewModel.self) private var viewModel
    @Environment(WindowState.self) private var window
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @State private var showBibleNavigation: Bool = false
    @State private var showFontThemeConfig: Bool = false
    @State private var showLabs: Bool = false
    @State private var showReminder: Bool = false
    @State private var showAccount: Bool = false
    @State private var addBookmarkRequest: AddBookmarkRequest?
    @State private var exportRequest: VerseExportRequest?
    @State private var shareItem: ShareTextItem?
    @State private var highlightTask: Task<Void, Error>?
    @State private var ttsViewModel: TTSViewModel = DIContainer.shared.resolve(type: TTSViewModel.self)
    @State private var screenWake = ScreenWakeController()
    /// Measured width of the reader content (≈ the window width). Passed to the toolbar
    /// title so it caps itself to the real available space and shrinks to fit a cramped
    /// top bar (e.g. a narrow iPad window) instead of being dropped — the shrink decision
    /// is real measured width, not a size-class guess.
    @State private var availableWidth: CGFloat = 0
    /// Window x of the paged reader's verse column; the toolbar title aligns to it.
    @State private var pagedTextLeadingX: CGFloat?
    /// Window x of the scroll list's leading edge; the verse column starts a row's
    /// padding plus the user's side margin in from it.
    @State private var scrollListLeadingX: CGFloat?
    /// A tab bar pill over the page (foldable trailing column), in window coordinates.
    @State private var pagedTabBarOcclusion: CGRect?
    @State private var readerTrailingX: CGFloat = 0

    @State var selectStartIndex: Int?
    @State var selectEndIndex: Int?
    
    @ViewBuilder
    private var verseList: some View {
        BibleVerseListView(
            verses: viewModel.bibleVerseList,
            language: viewModel.bibleVersion?.language ?? "English",
            fontConfiguration: fontThemeManager.fontConfiguration,
            theme: fontThemeManager.theme,
            highlightedVerseNum: viewModel.navigatedVerseNum,
            ttsCurrentVerseIndex: ttsViewModel.isReading(viewModel) ? ttsViewModel.currentVerseIndex : nil,
            bookmarkStripesPerVerse: viewModel.isBookmarkIndicatorEnabled ? viewModel.bookmarkStripesPerVerse : [:],
            // Only render comparison rows once the version (and thus its
            // language/font) is resolved, to avoid a wrong-font first frame.
            compareTextByVerse: viewModel.compareVersion != nil ? viewModel.compareTextByVerse : [:],
            compareLanguage: viewModel.compareVersion?.language ?? "English",
            isComparisonOn: viewModel.isComparisonOn,
            // From the context menu there may be no selection yet; select the
            // verse(s) first so the action bar (which hosts + anchors the dialog)
            // is on screen, then present on the next hop once it has laid out.
            onCompareCopy: { start, end in
                selectStartIndex = start
                selectEndIndex = end
                Task { @MainActor in
                    exportRequest = VerseExportRequest(startIndex: start, endIndex: end, mode: .copy)
                }
            },
            onCompareShare: { start, end in
                selectStartIndex = start
                selectEndIndex = end
                Task { @MainActor in
                    exportRequest = VerseExportRequest(startIndex: start, endIndex: end, mode: .share)
                }
            },
            onAddBookmark: { start, end in
                requestAddBookmark(start: start, end: end)
            },
            onRowHeightChange: { index, height in
                verseRowHeights[index] = height
            },
            selectStartIndex: $selectStartIndex,
            selectEndIndex: $selectEndIndex
        )
        .safeAreaPadding(.bottom, 200)
    }

    /// The default reading surface: the verse list in a vertical scroll view, with the
    /// chapter swipe, TTS follow-scroll and navigation scroll-to attached.
    private var scrollingReader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                verseList
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minX
            } action: { scrollListLeadingX = $0 }
            // `containerSize` is already the visible reading area (nav bar bottom to
            // the bottom safe-area inset), which is the same rect `scrollTo(anchor:)`
            // aligns against. Do not subtract `contentInsets` again.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.height
            } action: { _, height in
                visibleReadingHeight = height
            }
            .onScrollPhaseChange { _, _ in
                // Every scroll-phase change — including the transition back to
                // .idle when momentum stops — counts as interaction, so the dim
                // countdown restarts the moment scrolling settles rather than mid-fling.
                screenWake.userDidInteract(
                    keepScreenOn: appState.keepScreenOn,
                    dimAfterSeconds: appState.screenDimAfterSeconds
                )
            }
            // Any touch on the reading surface — a tap, the start of a scroll or a
            // chapter swipe — holds off dimming for its full duration: the screen
            // can't dim under a finger, and a touch while dimmed undims *and* scrolls
            // because the recognizer never blocks the touch (see `TouchActivityDetector`).
            .gesture(
                TouchActivityDetector { active in
                    screenWake.setTouchActive(
                        active,
                        keepScreenOn: appState.keepScreenOn,
                        dimAfterSeconds: appState.screenDimAfterSeconds
                    )
                }
            )
            .swipeGesture(
                navigationToken: viewModel.bibleNavigationUpdateTrigger,
                onLeftSwipe: {
                    let wasActive = ttsViewModel.isReading(viewModel)
                    Task {
                        await viewModel.goToPreviousChapterAsync()
                        viewModel.bibleNavigationUpdateTrigger.toggle()
                        if wasActive {
                            ttsViewModel.switchChapter(from: viewModel)
                        }
                    }
                },
                onRightSwipe: {
                    let wasActive = ttsViewModel.isReading(viewModel)
                    Task {
                        await viewModel.goToNextChapterAsync()
                        viewModel.bibleNavigationUpdateTrigger.toggle()
                        if wasActive {
                            ttsViewModel.switchChapter(from: viewModel)
                        }
                    }
                }
            )
            .onChange(of: viewModel.bibleNavigationUpdateTrigger, initial: false) {
                selectStartIndex = nil
                selectEndIndex = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.linear(duration: 0.3)) {
                        // List ids are 1-based verse ordinals with 0 = top (see
                        // BibleVerseListView). `verseNum - 1` is intentional: the verse
                        // before the target rests at the top so the highlighted target
                        // sits one line down with context; no verse → 0 → chapter top.
                        proxy.scrollTo((viewModel.navigatedVerseNum ?? 1) - 1, anchor: .top)
                    }
                }
            }
            .onChange(of: ttsViewModel.currentVerseIndex) { _, newIndex in
                if ttsViewModel.isReading(viewModel) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // `currentVerseIndex` is 0-based; +1 targets the spoken verse's
                        // own row (not the one before it). The anchor is solved per verse
                        // from the row's height so its top edge lands on the follow line;
                        // `scrollTo` still clamps at the chapter's start and end.
                        proxy.scrollTo(
                            newIndex + 1,
                            anchor: TTSFollowScroll.anchor(
                                rowHeight: verseRowHeights[newIndex],
                                visibleHeight: visibleReadingHeight
                            )
                        )
                    }
                }
            }
        }
    }

    /// Labs "Page Turning" surface: the chapter typeset into book pages with a page-curl
    /// flip, two pages side by side in landscape (or around the fold of a foldable).
    /// Chapters flow into one another, so a flip past the last page lands in the next
    /// chapter (the view model follows via `onPageChanged`). Tap-to-select, the long-press
    /// menu and bookmark stripes work as in scroll mode; the selection indices are the
    /// same 0-based verse indices, so the action bar and export flow are shared as-is.
    private var pagedReader: some View {
        // The page view runs under the bars so the curl is full-screen; the safe area is
        // handed in so the text (and footer) stay clear of them.
        GeometryReader { proxy in
            pagedReaderView(contentInsets: proxy.safeAreaInsets)
                .ignoresSafeArea()
        }
    }

    private func pagedReaderView(contentInsets: EdgeInsets) -> some View {
        PagedBibleReaderView(
            content: viewModel.pagedChapterContent,
            contentInsets: contentInsets,
            style: .make(
                fontConfiguration: fontThemeManager.fontConfiguration,
                theme: fontThemeManager.theme,
                language: viewModel.bibleVersion?.language ?? "English",
                compareLanguage: viewModel.compareVersion?.language ?? "English"
            ),
            isSpreadEnabled: appState.isPagedSpreadEnabled,
            highlightedVerseNum: viewModel.navigatedVerseNum,
            ttsVerseIndex: ttsViewModel.isReading(viewModel) ? ttsViewModel.currentVerseIndex : nil,
            selectedVerses: selectStartIndex.map { start in (start + 1)...((selectEndIndex ?? start) + 1) },
            bookmarkStripes: viewModel.isBookmarkIndicatorEnabled ? viewModel.bookmarkStripesPerVerse : [:],
            navigationToken: viewModel.bibleNavigationUpdateTrigger,
            targetVerse: viewModel.navigatedVerseNum ?? viewModel.verseNum,
            fetchNeighbor: { key, forward in
                guard let adjacent = viewModel.adjacentChapter(bookCode: key.bookCode, chapter: key.chapter, forward: forward) else {
                    return nil
                }
                return await viewModel.fetchPagedChapterContent(bookCode: adjacent.bookCode, chapter: adjacent.chapter)
            },
            onPageChanged: handlePagedPositionChange,
            onUserInteraction: {
                screenWake.userDidInteract(
                    keepScreenOn: appState.keepScreenOn,
                    dimAfterSeconds: appState.screenDimAfterSeconds
                )
            },
            onVerseTapped: { verse in
                (selectStartIndex, selectEndIndex) = BibleVerseListView.selection(
                    afterTapping: verse - 1, start: selectStartIndex, end: selectEndIndex
                )
            },
            contextMenu: pagedVerseMenu,
            onTextLeadingChanged: { pagedTextLeadingX = $0 },
            onTabBarOcclusionChanged: { pagedTabBarOcclusion = $0 }
        )
    }

    /// Where the scroll reader's verse numbers start, in window coordinates (the row's
    /// two 8pt paddings plus the side margin); computed, so a margin change lands at once.
    private var scrollTextLeadingX: CGFloat? {
        scrollListLeadingX.map { $0 + BibleVerseListView.verseRowLeadingInset + CGFloat(fontThemeManager.fontConfiguration.sideMargin) }
    }

    /// Trailing room the floating action bar leaves for a tab bar pill that sits in the
    /// page's trailing column (a foldable's), so the two never overlap.
    private var pagedActionBarTrailingPadding: CGFloat {
        guard let pill = pagedTabBarOcclusion, pill.minX < readerTrailingX else { return 0 }
        return readerTrailingX - pill.minX + 8
    }

    /// The paged reader's long-press menu: the same three actions as the scroll reader's
    /// context menu, acting on the selection when the pressed verse is inside it.
    private func pagedVerseMenu(forVerse verse: Int) -> UIMenu? {
        let index = verse - 1
        guard viewModel.bibleVerseList.indices.contains(index) else { return nil }
        var start = index, end = index
        if let selectStartIndex, let selectEndIndex, (selectStartIndex...selectEndIndex).contains(index) {
            start = selectStartIndex
            end = selectEndIndex
        }
        let text = { viewModel.makeExportText(startIndex: start, endIndex: end, scope: .main) }
        let isComparisonOn = viewModel.isComparisonOn
        // With comparison on, select first so the action bar (which hosts the version
        // dialog) is on screen, then present the dialog on the next hop — as in scroll mode.
        func requestExport(_ mode: VerseExportRequest.Mode) {
            selectStartIndex = start
            selectEndIndex = end
            Task { @MainActor in
                exportRequest = VerseExportRequest(startIndex: start, endIndex: end, mode: mode)
            }
        }
        return UIMenu(children: [
            UIAction(title: String(localized: "Add bookmark"), image: UIImage(systemName: "bookmark")) { _ in
                requestAddBookmark(start: start, end: end)
            },
            UIAction(title: String(localized: "Copy to clipboard"), image: UIImage(systemName: "doc.on.doc")) { _ in
                if isComparisonOn {
                    requestExport(.copy)
                } else {
                    UIPasteboard.general.string = text()
                    selectStartIndex = nil
                    selectEndIndex = nil
                }
            },
            UIAction(title: String(localized: "Share"), image: UIImage(systemName: "square.and.arrow.up")) { _ in
                if isComparisonOn {
                    requestExport(.share)
                } else {
                    shareItem = ShareTextItem(text: text())
                }
            },
        ])
    }

    /// Shared by both reading surfaces; see `body` for where each hosts it.
    private var actionBar: some View {
        BibleReaderActionBar(
            selectStartIndex: $selectStartIndex,
            selectEndIndex: $selectEndIndex,
            bibleVerseList: viewModel.bibleVerseList,
            onBookmarkTapped: {
                guard let start = selectStartIndex else { return }
                let end = selectEndIndex ?? start
                requestAddBookmark(start: start, end: end)
            },
            isComparisonOn: viewModel.isComparisonOn,
            onCompareCopy: { start, end in
                exportRequest = VerseExportRequest(startIndex: start, endIndex: end, mode: .copy)
            },
            onCompareShare: { start, end in
                exportRequest = VerseExportRequest(startIndex: start, endIndex: end, mode: .share)
            },
            // The dialog is attached to the matching action-bar button so
            // it appears as a bubble pointing at the tapped button.
            exportDialogMode: exportDialogMode,
            exportDialogTitle: exportDialogTitle,
            exportMainVersionName: viewModel.bibleVersion?.versionName ?? "Version A",
            exportCompareVersionName: viewModel.compareVersion?.versionName ?? "Version B",
            onExportScopeChosen: { scope in
                if let request = exportRequest {
                    performExport(request, scope: scope)
                }
            },
            onExportCancel: {
                exportRequest = nil
            }
        )
        .ignoresSafeArea(edges: .horizontal)
    }

    /// A page flip settled on `firstVerse` of `key`. Inside the current chapter that just
    /// records the position (so the app reopens on the same page); in a neighbouring
    /// chapter it moves the reader there — the same work the chapter swipe does in
    /// scroll mode, including handing TTS the new chapter. The navigation trigger is not
    /// toggled: the pages are already showing the right place.
    private func handlePagedPositionChange(_ key: ChapterKey, _ firstVerse: Int) {
        if key.bookCode == viewModel.bookCode, key.chapter == viewModel.chapterNum {
            viewModel.verseNum = firstVerse
            viewModel.fetchBibleVerse()
            return
        }
        let wasActive = ttsViewModel.isReading(viewModel)
        Task {
            await viewModel.applyBibleSelectionAsync(bookCode: key.bookCode, chapterNum: key.chapter, verseNum: firstVerse)
            selectStartIndex = nil
            selectEndIndex = nil
            if wasActive {
                ttsViewModel.switchChapter(from: viewModel)
            }
        }
    }

    /// True while any modal is open over the reader (Bible Navigation, Font & Themes,
    /// Labs, Reading Reminder, Add Bookmark, the export dialog, or the share sheet).
    /// Dimming is suppressed while one is up, so it only fires during actual reading.
    private var isReaderModalOpen: Bool {
        showBibleNavigation
            || showFontThemeConfig
            || showLabs
            || showReminder
            || showAccount
            || addBookmarkRequest != nil
            || exportRequest != nil
            || shareItem != nil
    }

    /// Push the current screen-wake settings into the controller — but only while
    /// the reader tab is active, so dimming/keep-awake never applies on other tabs
    /// (e.g. coming back from background while Library is selected).
    private func applyScreenWake() {
        guard window.selectedTab == .bibleReader else {
            screenWake.teardown()
            return
        }
        // Keep the screen awake, but suppress dimming (delay 0 = never) while a
        // modal is open over the reader; the real delay resumes once it closes.
        let dimAfterSeconds = isReaderModalOpen ? 0 : appState.screenDimAfterSeconds
        screenWake.apply(
            keepScreenOn: appState.keepScreenOn,
            dimAfterSeconds: dimAfterSeconds
        )
    }

    /// Laid-out height of each verse row by index, fed by the list. Read together with
    /// `visibleReadingHeight` to compute a per-verse anchor that parks the spoken verse's
    /// top edge on `TTSFollowScroll.line` (see that type for why a fixed anchor drifts).
    /// Entries are never cleared: on-screen rows re-report as soon as a chapter changes,
    /// and a not-yet-laid-out row just falls back to the plain fraction for one scroll.
    @State private var verseRowHeights: [Int: CGFloat] = [:]
    /// Height of the scroll view's visible area (`ScrollGeometry.containerSize.height`):
    /// the region between the toolbar and the action bar that `scrollTo` anchors are
    /// measured in.
    @State private var visibleReadingHeight: CGFloat = 0

    /// True once the reader has re-fetched after the launch download routine finished,
    /// so `bibleVersion == nil` means "nothing is downloaded" rather than "not loaded yet".
    @State private var hasResolvedContent = false
    /// The fallback notice currently on screen (copied out of the view model so it can
    /// be dismissed on a timer without racing a later fetch).
    @State private var fallbackNotice: String?
    @State private var fallbackNoticeTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if appState.isPagedReadingEnabled {
                    pagedReader
                } else {
                    scrollingReader
                }
            }
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .overlay {
                if hasResolvedContent, viewModel.bibleVersion == nil {
                    noBibleDownloadedView
                }
            }
            .overlay(alignment: .top) {
                contentStatusBanner
                    .animation(.easeInOut(duration: 0.25), value: appState.bibleContentUpdateStatus)
            }
            .onChange(of: viewModel.navigatedVerseNum) {
                if viewModel.navigatedVerseNum != nil {
                    highlightTask?.cancel()
                    highlightTask = Task {
                        try await Task.sleep(for: .seconds(3))
                        viewModel.navigatedVerseNum = nil
                    }
                }
            }
            .background(Color.gray.opacity(0.2), ignoresSafeAreaEdges: .all)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                availableWidth = newWidth
            }
            .toolbarTitleDisplayMode(.inline)
            // In scroll mode the bar insets the safe area (the list scrolls above it). In
            // page mode it floats instead: an inset would shrink the page area and
            // re-typeset every page each time a selection starts or ends.
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                if !appState.isPagedReadingEnabled { actionBar }
            }
            .overlay(alignment: .bottomTrailing) {
                if appState.isPagedReadingEnabled { actionBar.padding(.trailing, pagedActionBarTrailingPadding) }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxX
            } action: { readerTrailingX = $0 }
            .toolbar {
                BibleReaderToolbarContent(
                    bibleBook: viewModel.bibleBook,
                    chapterNum: viewModel.chapterNum,
                    bibleVersion: viewModel.bibleVersion,
                    availableWidth: availableWidth,
                    alignedLeadingX: appState.isPagedReadingEnabled ? pagedTextLeadingX : scrollTextLeadingX,
                    showBibleNavigation: $showBibleNavigation,
                    showFontThemeConfig: $showFontThemeConfig,
                    onListenTapped: handleListenTapped,
                    ttsPlaybackState: ownTTSPlaybackState,
                    isTTSEnabled: appState.isTTSEnabled,
                    onLabsTapped: { showLabs = true },
                    onReminderTapped: { showReminder = true },
                    onAccountTapped: { showAccount = true },
                    onBookmarksTapped: {
                        window.librarySection = .bookmarks
                        window.selectedTab = .library
                    },
                    onReadingChecklistTapped: {
                        window.pendingReadingScrollBookOrder = viewModel.bibleBook?.bookOrder
                        window.librarySection = .reading
                        window.selectedTab = .library
                    },
                    onNewWindowTapped: newWindowAction,
                    comparableVersions: viewModel.comparableVersions,
                    compareVersionCode: viewModel.compareVersionCode,
                    onSelectCompareVersion: { code in
                        Task { await viewModel.setCompareVersion(code) }
                    }
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBibleNavigation) {
//                BibleNavigationView(
//                    selectedVersion: viewModel.bibleVersion,
//                    selectedBook: viewModel.bibleBook,
//                    selectedChapter: viewModel.bibleChapter,
//                    selectedVerse: viewModel.bibleVerse,
//                )
//                    .environment(viewModel)
//                    .presentationDetents([.small])
                BibleNavigation2View(
                    selectedVersion: viewModel.bibleVersion,
                    selectedBook: viewModel.bibleBook,
                    selectedChapter: viewModel.bibleChapter,
                    selectedVerse: viewModel.bibleVerse,
                )
                    .environment(viewModel)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showFontThemeConfig) {
                FontThemeConfigView(language: viewModel.bibleVersion?.language ?? "English")
                    .environment(fontThemeManager)
                    .presentationDetents(horizontalSizeClass == .compact ? [.medium] : [.large])
                    .if(horizontalSizeClass != .compact) { view in
                        view
                            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
                    }
            }
            .sheet(isPresented: $showLabs) {
                ExperimentalFeaturesView(appState: appState)
            }
            .sheet(isPresented: $showReminder) {
                ReadingReminderView(appState: appState)
            }
            .sheet(isPresented: $showAccount) {
                AccountSyncView(viewModel: DIContainer.shared.resolve(type: SyncAccountViewModel.self))
            }
            .sheet(item: $addBookmarkRequest) { request in
                AddBookmarkSheet(
                    bookCode: request.bookCode,
                    bookOrder: request.bookOrder,
                    chapter: request.chapter,
                    startVerse: request.startVerse,
                    endVerse: request.endVerse,
                    onSaved: {
                        selectStartIndex = nil
                        selectEndIndex = nil
                        Task { await viewModel.fetchBookmarksForCurrentChapter() }
                    }
                )
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.text])
        }
        .onChange(of: window.selectedTab) { _, tab in
            // Returning from the Library tab (where bookmarks can be added/edited/
            // deleted) — refresh the reader's per-chapter stripes.
            if tab == .bibleReader {
                Task { await viewModel.fetchBookmarksForCurrentChapter() }
            }
            // Screen-wake/dim follows the active tab: re-arm on the reader, tear
            // down on any other tab (applyScreenWake self-gates on selectedTab).
            applyScreenWake()
        }
        .onAppear { applyScreenWake() }
        .onChange(of: appState.keepScreenOn) { applyScreenWake() }
        .onChange(of: appState.screenDimAfterSeconds) { applyScreenWake() }
        .onChange(of: isReaderModalOpen) { applyScreenWake() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                applyScreenWake()
            case .inactive, .background:
                // Don't leave another app at our dimmed brightness.
                screenWake.suspend()
            @unknown default:
                break
            }
        }
        .task {
            await reloadContent()
        }
        .onChange(of: appState.bibleContentRevision) { _, _ in
            // Bible files changed on disk (launch routine finished, or a background
            // update swapped a file in): re-resolve the version and reload the chapter.
            Task { await reloadContent() }
        }
        .onChange(of: viewModel.versionFallbackNotice) { _, notice in
            guard let notice else { return }
            viewModel.versionFallbackNotice = nil
            fallbackNoticeTask?.cancel()
            withAnimation { fallbackNotice = notice }
            fallbackNoticeTask = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation { fallbackNotice = nil }
            }
        }
        .onDisappear {
            screenWake.teardown()
        }
    }

    // MARK: - Content availability

    /// Re-resolves the version (with fallback) and reloads the chapter. Shared by the
    /// first appearance and every `bibleContentRevision` bump: after a fresh install the
    /// reader is created only once the blocking loading view goes away, so the bump that
    /// ended the download has already happened and only the `.task` path runs.
    private func reloadContent() async {
        await viewModel.fetchAvailableVersions()
        await viewModel.fetchBibleVersion()
        await viewModel.fetchBibleBook()
        await viewModel.fetchBibleChapter()
        viewModel.fetchBibleVerse()
        if appState.initialDownloadCompleted {
            hasResolvedContent = true
        }
    }

    /// Small floating capsule under the toolbar: progress while a version downloads or
    /// updates in the background, or the one-off notice that the reader fell back to
    /// another version. Nothing when neither applies.
    @ViewBuilder
    private var contentStatusBanner: some View {
        if let status = appState.bibleContentUpdateStatus {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(status)
            }
            .modifier(StatusBannerStyle())
        } else if let fallbackNotice {
            Label(fallbackNotice, systemImage: "arrow.triangle.2.circlepath")
                .modifier(StatusBannerStyle())
        }
    }

    /// Shown instead of a blank page when no Bible version is on the device (first
    /// launch offline, or every download failed). "Retry" re-runs the launch download.
    private var noBibleDownloadedView: some View {
        ContentUnavailableView {
            Label("No Bible Downloaded", systemImage: "book.closed")
        } description: {
            Text("Connect to the internet to download a Bible version.")
        } actions: {
            Button("Retry") {
                hasResolvedContent = false
                appState.bibleDownloadRetryRequest += 1
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var exportDialogTitle: String {
        switch exportRequest?.mode {
        case .copy: return "Select version to copy"
        case .share: return "Select version to share"
        case .none: return ""
        }
    }

    /// Maps the pending request to the action-bar button the dialog anchors to.
    private var exportDialogMode: VerseExportDialogMode? {
        switch exportRequest?.mode {
        case .copy: return .copy
        case .share: return .share
        case .none: return nil
        }
    }

    /// Builds the text for the chosen version scope, then copies it or presents
    /// the share sheet. Share presentation is deferred one main-actor hop so the
    /// dialog finishes dismissing first (avoids a presentation conflict).
    private func performExport(_ request: VerseExportRequest, scope: BibleReaderViewModel.VerseExportScope) {
        let text = viewModel.makeExportText(startIndex: request.startIndex, endIndex: request.endIndex, scope: scope)
        exportRequest = nil
        selectStartIndex = nil
        selectEndIndex = nil
        guard !text.isEmpty else { return }
        switch request.mode {
        case .copy:
            UIPasteboard.general.string = text
        case .share:
            Task { @MainActor in
                shareItem = ShareTextItem(text: text)
            }
        }
    }

    private func requestAddBookmark(start: Int, end: Int) {
        addBookmarkRequest = AddBookmarkRequest(
            bookCode: viewModel.bookCode,
            bookOrder: viewModel.bibleBook?.bookOrder ?? 1,
            chapter: viewModel.chapterNum,
            startVerse: start + 1,
            endVerse: end + 1
        )
    }

    // MARK: - TTS Methods
    /// The Listen button reflects only a session reading from this window's reader; another
    /// window's session leaves it at "Listen" (tapping takes the session over).
    private var ownTTSPlaybackState: TTSPlaybackState {
        ttsViewModel.isReading(viewModel) ? ttsViewModel.playbackState : .idle
    }

    /// Opens another window of the app (iPad, foldables); nil hides the menu entry.
    private var newWindowAction: (() -> Void)? {
        guard supportsMultipleWindows else { return nil }
        return { openWindow(id: "main") }
    }

    private func handleListenTapped() {
        // Defense in depth: the Listen action is hidden when TTS is disabled, but
        // guard here too so a session can never start while the feature is off.
        guard appState.isTTSEnabled else { return }
        if ttsViewModel.isReading(viewModel) {
            // Stop TTS and hide accessory view
            ttsViewModel.stop()
        } else {
            // Start from selected verse or beginning. A session another window started is
            // taken over, not stopped: Listen here means "read this chapter".
            let startIndex = selectStartIndex ?? 0
            ttsViewModel.startReading(from: viewModel, startIndex: startIndex)
            selectStartIndex = nil
            selectEndIndex = nil
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}

/// Capsule chrome for the reader's transient status banner.
private struct StatusBannerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}
