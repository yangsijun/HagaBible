//
//  ContentView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import OSLog
import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = DIContainer.shared.resolve(type: AppState.self)
    @State private var ttsViewModel = DIContainer.shared.resolve(type: TTSViewModel.self)
    @State private var search: String = ""
    @State private var searchPresented: Bool = false

    @State private var showLoadingView: Bool = false
    @State private var downloadProgress: String = ""
    @State private var showFullPlayer: Bool = false
    @State private var fontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    /// This window's state (tab, Library routing, reader/navigation view models). One
    /// `RootView` per window, so a second window on iPad gets its own chapter and tabs.
    @State private var window: WindowState
    @State private var searchViewModel: SearchViewModel

    init() {
        let window = DIContainer.makeWindowState()
        _window = State(initialValue: window)
        _searchViewModel = State(initialValue: DIContainer.makeSearchViewModel(window: window))
    }

    /// External requests (App Intents, the Control Center control) go to the window that was
    /// active last; before any window has been active (cold launch) the first one takes them.
    private var handlesExternalRequests: Bool {
        appState.activeWindow == nil || appState.activeWindow === window
    }

    // Default versions auto-downloaded on first launch must be FREE — bundling a
    // paid version here would hand out purchased content without payment. KRV
    // (개역한글) is the free Korean default; the paid 개역개정 (NKRV) is acquired
    // through the version store instead.
    private let defaultVersions = ["WEBBE", "KRV"]

    var body: some View {
        Group {
            if showLoadingView {
                InitialLoadingView(progressText: downloadProgress)
            } else {
                mainContent
            }
        }
        // Here rather than on the `WindowGroup`: reading the theme in `App.body` would rebuild
        // `RootView` (and a throwaway `WindowState`) on every theme change.
        .preferredColorScheme(fontThemeManager.colorScheme)
        // Re-runs when the reader's empty-state "Retry" bumps the request counter.
        .task(id: appState.bibleDownloadRetryRequest) {
            await downloadDefaultVersionsIfNeeded()
        }
        .task {
            // Keep the OS schedule in sync with the saved reminder list on launch (e.g.
            // a reminder fired/changed while the app was closed). Only reconcile while
            // still authorized so we don't prompt for permission at every launch.
            let service = DIContainer.shared.resolve(type: NotificationService.self)
            if await service.isAuthorized() {
                await service.syncReadingReminders(appState.readingReminders)
            }
        }
        .task {
            // Pull/push on launch if a synced account is signed in (no-op otherwise).
            await DIContainer.shared.resolveOptional(type: SyncAccountViewModel.self)?.sync()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appState.activeWindow = window
            // Recover a TTS session that iOS silently deactivated while the app was
            // suspended (mini player shows, marked "playing", but no audio comes out).
            ttsViewModel.handleForegroundTransition()
            // The reader is on screen again, so close the TTS PiP window that opened
            // when the user left (iOS keeps it floating over the app otherwise).
            DIContainer.shared.resolve(type: TTSPictureInPictureService.self).stopForForegroundReturn()
            Task {
                await DIContainer.shared.resolveOptional(type: SyncAccountViewModel.self)?.sync()
            }
        }
    }

    private var mainContent: some View {
        TabView(selection: $window.selectedTab) {
            Tab("Bible", systemImage: "book.fill", value: .bibleReader) {
                BibleReaderView()
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            Tab("Library", systemImage: "books.vertical.fill", value: .library) {
                LibraryView(window: window)
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            if appState.isRecordingEnabled {
                Tab("Recordings", systemImage: "waveform", value: .recordings) {
                    RecordingsView()
                        .environment(\.horizontalSizeClass, horizontalSizeClass)
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(searchText: $search)
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
                    .searchable(text: $search, isPresented: $searchPresented)
            }
        }
        .applyTabBarMinimizeBehavior()
        .applyTTSBottomAccessory(isEnabled: appState.isTTSEnabled, ttsViewModel: ttsViewModel, showFullPlayer: $showFullPlayer)
        // Only the window whose reader the session reads from hosts the PiP layer; two hosts
        // would fight over the one service.
        .applyTTSPiPHost(isEnabled: appState.isTTSEnabled && ttsViewModel.reader === window.reader, ttsViewModel: ttsViewModel)
        .environment(\.horizontalSizeClass, .compact)
        .environment(window)
        .environment(window.reader)
        .environment(window.navigation)
        .environment(searchViewModel)
        .onAppear {
            ttsViewModel.onChapterFinished = { [ttsViewModel] in
                ttsViewModel.goToNextChapter(forcePlay: true)
            }
        }
        .onChange(of: appState.isTTSEnabled) { _, enabled in
            // Disabling TTS mid-session must stop playback — the mini player is gated
            // on isTTSEnabled and would otherwise vanish while audio keeps playing.
            if !enabled { ttsViewModel.stop() }
        }
        .onChange(of: appState.isRecordingEnabled) { _, enabled in
            if enabled {
                // Ask for mic permission when recording is turned on, so the prompt
                // appears here rather than at every app launch.
                DIContainer.shared.resolve(type: AudioService.self).requestMicrophonePermissionIfNeeded()
            } else if window.selectedTab == .recordings {
                // The Recordings tab is about to disappear; fall back to the reader so
                // the TabView isn't left on a now-missing tab.
                window.selectedTab = .bibleReader
            }
        }
        // An App Shortcut / Siri / Spotlight reference sets `pendingReaderNavigation`; the
        // active window moves its reader there. On change and on appear, like the search below.
        .onChange(of: appState.pendingReaderNavigation) { _, _ in applyPendingNavigationIfNeeded() }
        // An App Shortcut / Siri / Spotlight text search sets `pendingSearchQuery`; copy
        // it into the `.searchable` field (which fires the existing search pipeline) and
        // clear it. Applied both on change and on appear so a value the intent set before
        // this view existed (cold launch) still lands.
        .onChange(of: appState.pendingSearchQuery) { _, _ in applyPendingSearchIfNeeded() }
        // The Control Center "Bible Search" control asks for the search field to take focus.
        .onChange(of: appState.pendingSearchFocus) { _, _ in applyPendingSearchFocusIfNeeded() }
        .onAppear {
            if appState.activeWindow == nil { appState.activeWindow = window }
            applyPendingNavigationIfNeeded()
            applyPendingSearchIfNeeded()
            applyPendingSearchFocusIfNeeded()
        }
    }

    private func applyPendingNavigationIfNeeded() {
        guard handlesExternalRequests, let request = appState.pendingReaderNavigation else { return }
        appState.pendingReaderNavigation = nil
        Task {
            await window.showReader(
                versionCode: request.versionCode,
                bookCode: request.bookCode,
                chapter: request.chapter,
                verse: request.verse
            )
        }
    }

    private func applyPendingSearchIfNeeded() {
        guard handlesExternalRequests, let query = appState.pendingSearchQuery else { return }
        let versionCode = appState.pendingSearchVersionCode
        appState.pendingSearchQuery = nil
        appState.pendingSearchVersionCode = nil
        Task {
            // The search runs against the reader's version, so switch first and await it.
            if let versionCode {
                await window.reader.applyBibleSelectionAsync(versionCode: versionCode)
            }
            search = query
            window.selectedTab = .search
        }
    }

    private func applyPendingSearchFocusIfNeeded() {
        guard handlesExternalRequests, appState.pendingSearchFocus else { return }
        window.selectedTab = .search
        appState.pendingSearchFocus = false
        // Defer so the Search tab's `.searchable` field is installed before we focus it —
        // on a cold launch from the control the flag is set before this view (and the tab)
        // exists, so focusing synchronously would no-op.
        Task { @MainActor in
            searchPresented = true
        }
    }

    /// Brings the on-device Bible files in line with this build at launch.
    ///
    /// Two kinds of work, and the user experience differs on purpose:
    /// - **Missing defaults** (`defaultVersions` not downloaded). When *nothing* is
    ///   downloaded — a fresh install — the app has nothing to show, so the full-screen
    ///   loading view covers the download. When some version is readable the download
    ///   runs in the background instead.
    /// - **Outdated files** (`BibleDatabaseService.outdatedVersionCodes`: installed, but
    ///   from an older content version). The old file stays readable while the new one
    ///   downloads; the install swaps the file and re-attaches it, then
    ///   `bibleContentRevision` tells the reader to re-fetch. A failure leaves the old file
    ///   in place and the same check retries on the next launch, so the reader is never
    ///   blank because of an update.
    private func downloadDefaultVersionsIfNeeded() async {
        let bibleFileRepository = DIContainer.shared.resolve(type: BibleFileRepository.self)
        let bibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)
        let bibleDatabaseService = DIContainer.shared.resolve(type: BibleDatabaseService.self)

        var missingVersions: [BibleVersion] = []
        var outdatedVersions: [BibleVersion] = []
        var hasReadableVersion = false

        do {
            let allVersions = try await bibleRepository.fetchBibleVersionList()
            hasReadableVersion = allVersions.contains(where: \.isDownloaded)

            for versionCode in defaultVersions {
                if let version = allVersions.first(where: { $0.versionCode == versionCode }),
                   !version.isDownloaded {
                    missingVersions.append(version)
                }
            }

            for versionCode in bibleDatabaseService.outdatedVersionCodes {
                if let version = allVersions.first(where: { $0.versionCode == versionCode }),
                   !missingVersions.contains(where: { $0.versionCode == versionCode }) {
                    outdatedVersions.append(version)
                }
            }

            // Entitlement gate: never auto-download a paid version the user does
            // not own. Free versions always pass; paid versions only (re)download
            // when the on-device entitlement is present. An outdated paid file that
            // fails the gate simply stays as it is.
            let candidates = missingVersions + outdatedVersions
            if candidates.contains(where: { !BibleVersionPurchaseCatalog.isFree($0.versionCode) }) {
                let store = DIContainer.shared.resolve(type: BibleVersionStore.self)
                let owned = await store.purchasedProductIDs()
                let isAllowed: (BibleVersion) -> Bool = { version in
                    guard let productID = BibleVersionPurchaseCatalog.productID(for: version.versionCode) else {
                        return true // free
                    }
                    return owned.contains(productID)
                }
                missingVersions = missingVersions.filter(isAllowed)
                outdatedVersions = outdatedVersions.filter(isAllowed)
            }
        } catch {
            Logger.repository.error("Failed to fetch version list: \(error.localizedDescription)")
            appState.initialDownloadCompleted = true
            appState.bibleContentRevision += 1
            return
        }

        let queue = missingVersions + outdatedVersions
        if queue.isEmpty {
            appState.initialDownloadCompleted = true
            appState.bibleContentRevision += 1
            return
        }

        // Only a device with nothing to read gets the blocking loading view.
        let isBlocking = !hasReadableVersion && !missingVersions.isEmpty
        let showLoadingAfterDelayTask = Task {
            // Delayed so a fast download never flashes the loading view.
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled, isBlocking {
                showLoadingView = true
            }
        }

        for (index, version) in queue.enumerated() {
            let isUpdate = outdatedVersions.contains(where: { $0.versionCode == version.versionCode })
            let status = isUpdate
                ? String(localized: "Updating \(version.versionName)...")
                : String(localized: "Downloading \(version.versionName)... (\(index + 1)/\(queue.count))")
            downloadProgress = status
            if !isBlocking {
                appState.bibleContentUpdateStatus = status
            }

            do {
                try await bibleFileRepository.downloadAndInstall(version: version)
            } catch {
                Logger.repository.error("Failed to download \(version.versionCode): \(error.localizedDescription)")
            }
        }

        showLoadingAfterDelayTask.cancel()
        showLoadingView = false
        appState.bibleContentUpdateStatus = nil
        appState.initialDownloadCompleted = true
        // Always bump: even a failed batch may leave a different set of readable
        // versions than the reader assumed at first fetch.
        appState.bibleContentRevision += 1
    }
}

extension View {
    @ViewBuilder
    func applyTabBarMinimizeBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Embeds the near-invisible layer host that lets a Picture-in-Picture window open
    /// (auto-showing the text being read) when the user leaves the app mid-TTS session.
    /// Gated on `isSessionActive` — NOT `playbackState` — for the same re-host reason as
    /// the bottom accessory below: the host must survive play↔pause toggles, since
    /// recreating it would tear down the PiP controller mid-session.
    @ViewBuilder
    func applyTTSPiPHost(isEnabled: Bool, ttsViewModel: TTSViewModel) -> some View {
        if isEnabled, ttsViewModel.isSessionActive {
            self.background(alignment: .bottomTrailing) {
                TTSPiPLayerHostView(service: DIContainer.shared.resolve(type: TTSPictureInPictureService.self))
                    .frame(width: 1, height: 1)
                    // Not fully transparent: AVKit refuses PiP from an invisible layer.
                    .opacity(0.02)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyTTSBottomAccessory(isEnabled: Bool, ttsViewModel: TTSViewModel, showFullPlayer: Binding<Bool>) -> some View {
        if #available(iOS 26.0, *) {
            // Observe `isSessionActive` (flips only on session start/stop), NOT `playbackState`.
            // Reading `playbackState` here would re-run this builder on every play↔pause toggle,
            // re-hosting the accessory content and snapping the mini player's animations.
            // `isEnabled` is the Labs/TTS feature flag and only changes when the user toggles
            // the feature, so it doesn't reintroduce the play↔pause re-host.
            if isEnabled, ttsViewModel.isSessionActive {
                self.tabViewBottomAccessory {
                    TTSMiniPlayerView(
                        ttsViewModel: ttsViewModel,
                        onTap: { showFullPlayer.wrappedValue = true }
                    )
                }
                .sheet(isPresented: showFullPlayer) {
                    TTSFullPlayerView(ttsViewModel: ttsViewModel)
                }
            } else {
                self
            }
        } else {
            self
        }
    }
}

#Preview {
    RootView()
}
