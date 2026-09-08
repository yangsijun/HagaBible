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
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
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
            ttsCurrentVerseIndex: ttsViewModel.playbackState != .idle ? ttsViewModel.currentVerseIndex : nil,
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
        .onChange(of: viewModel.navigatedVerseNum) {
            if viewModel.navigatedVerseNum != nil {
                highlightTask?.cancel()
                highlightTask = Task {
                    try await Task.sleep(for: .seconds(3))
                    viewModel.navigatedVerseNum = nil
                }
            }
        }
        .safeAreaPadding(.bottom, 200)
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
        guard appState.selectedTab == .bibleReader else {
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
            ScrollViewReader { proxy in
                ScrollView {
                    verseList
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
                        let wasActive = ttsViewModel.playbackState != .idle
                        Task {
                            await viewModel.goToPreviousChapterAsync()
                            viewModel.bibleNavigationUpdateTrigger.toggle()
                            if wasActive {
                                let language = viewModel.bibleVersion?.language ?? "Korean"
                                ttsViewModel.switchChapter(verses: viewModel.bibleVerseList, language: language)
                            }
                        }
                    },
                    onRightSwipe: {
                        let wasActive = ttsViewModel.playbackState != .idle
                        Task {
                            await viewModel.goToNextChapterAsync()
                            viewModel.bibleNavigationUpdateTrigger.toggle()
                            if wasActive {
                                let language = viewModel.bibleVersion?.language ?? "Korean"
                                ttsViewModel.switchChapter(verses: viewModel.bibleVerseList, language: language)
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
                    if ttsViewModel.playbackState != .idle {
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
            .background(Color.gray.opacity(0.2), ignoresSafeAreaEdges: .all)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                availableWidth = newWidth
            }
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
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
            .toolbar {
                BibleReaderToolbarContent(
                    bibleBook: viewModel.bibleBook,
                    chapterNum: viewModel.chapterNum,
                    bibleVersion: viewModel.bibleVersion,
                    availableWidth: availableWidth,
                    showBibleNavigation: $showBibleNavigation,
                    showFontThemeConfig: $showFontThemeConfig,
                    onListenTapped: handleListenTapped,
                    ttsPlaybackState: ttsViewModel.playbackState,
                    isTTSEnabled: appState.isTTSEnabled,
                    onLabsTapped: { showLabs = true },
                    onReminderTapped: { showReminder = true },
                    onAccountTapped: { showAccount = true },
                    onBookmarksTapped: {
                        appState.librarySection = .bookmarks
                        appState.selectedTab = .library
                    },
                    onReadingChecklistTapped: {
                        appState.pendingReadingScrollBookOrder = viewModel.bibleBook?.bookOrder
                        appState.librarySection = .reading
                        appState.selectedTab = .library
                    },
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
        .onChange(of: appState.selectedTab) { _, tab in
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
    private func handleListenTapped() {
        // Defense in depth: the Listen action is hidden when TTS is disabled, but
        // guard here too so a session can never start while the feature is off.
        guard appState.isTTSEnabled else { return }
        if ttsViewModel.playbackState == .idle {
            // Start from selected verse or beginning
            let startIndex = selectStartIndex ?? 0
            let language = viewModel.bibleVersion?.language ?? "Korean"
            ttsViewModel.startReading(verses: viewModel.bibleVerseList, language: language, startIndex: startIndex)
            selectStartIndex = nil
            selectEndIndex = nil
        } else {
            // Stop TTS and hide accessory view
            ttsViewModel.stop()
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
