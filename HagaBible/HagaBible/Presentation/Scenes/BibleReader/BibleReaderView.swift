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
    @State private var isDraggingHorizontally = false
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

    /// Full-screen transparent catcher shown only while the screen is dimmed; any
    /// touch restores brightness and restarts the countdown (the device is never
    /// locked, so resume is just a tap — no Face ID / passcode).
    private var screenDimWakeCatcher: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { _ in
                    screenWake.userDidInteract(
                        keepScreenOn: appState.keepScreenOn,
                        dimAfterSeconds: appState.screenDimAfterSeconds
                    )
                }
            )
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    verseList
                }
                .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
                .onScrollPhaseChange { _, newPhase in
                    // Active scrolling counts as interaction — keep the screen lit
                    // and restart the dim countdown.
                    if newPhase != .idle {
                        screenWake.userDidInteract(
                            keepScreenOn: appState.keepScreenOn,
                            dimAfterSeconds: appState.screenDimAfterSeconds
                        )
                    }
                }
                // Any touch on the reading surface — a tap, the start of a scroll or a
                // chapter swipe — also counts, so the dim fires only after genuine
                // inactivity rather than on a fixed timer. The recognizer observes
                // without blocking scroll/taps (see `TouchActivityDetector`).
                .gesture(
                    TouchActivityDetector {
                        screenWake.userDidInteract(
                            keepScreenOn: appState.keepScreenOn,
                            dimAfterSeconds: appState.screenDimAfterSeconds
                        )
                    }
                )
                .swipeGesture(
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
                            proxy.scrollTo((viewModel.navigatedVerseNum ?? 1) - 1, anchor: .top)
                        }
                    }
                }
                .onChange(of: ttsViewModel.currentVerseIndex) { _, newIndex in
                    if ttsViewModel.playbackState != .idle {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .top)
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
                NavigationStack {
                    AccountSyncView(viewModel: DIContainer.shared.resolve(type: SyncAccountViewModel.self))
                }
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
            await viewModel.fetchAvailableVersions()
            await viewModel.fetchBibleVersion()
            await viewModel.fetchBibleBook()
            await viewModel.fetchBibleChapter()
            viewModel.fetchBibleVerse()
        }
        .onChange(of: appState.initialDownloadCompleted) { _, completed in
            if completed {
                // 초기 다운로드 완료 후 데이터 리로드
                Task {
                    await viewModel.fetchAvailableVersions()
                    await viewModel.fetchBibleVersion()
                    await viewModel.fetchBibleBook()
                    await viewModel.fetchBibleChapter()
                    viewModel.fetchBibleVerse()
                }
            }
        }
        .onDisappear {
            screenWake.teardown()
        }
        .overlay {
            if screenWake.isDimmed {
                screenDimWakeCatcher
            }
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
