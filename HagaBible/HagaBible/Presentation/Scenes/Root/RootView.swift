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
    @State private var appState = DIContainer.shared.resolve(type: AppState.self)
    @State private var ttsViewModel = DIContainer.shared.resolve(type: TTSViewModel.self)
    @State private var search: String = ""

    @State private var showLoadingView: Bool = false
    @State private var downloadProgress: String = ""
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @State private var showFullPlayer: Bool = false

    private let defaultVersions = ["WEBBE", "NKRV"]

    var body: some View {
        Group {
            if showLoadingView {
                InitialLoadingView(progressText: downloadProgress)
            } else {
                mainContent
            }
        }
        .task {
            await downloadDefaultVersionsIfNeeded()
        }
    }

    private var mainContent: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("Bible", systemImage: "book.fill", value: .bibleReader) {
                BibleReaderView()
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            Tab("Recordings", systemImage: "waveform", value: .recordings) {
                RecordingsView()
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(searchText: $search)
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
                    .searchable(text: $search)
            }
        }
        .applyTabBarMinimizeBehavior()
        .applyTTSBottomAccessory(ttsViewModel: ttsViewModel, showFullPlayer: $showFullPlayer)
        .environment(\.horizontalSizeClass, .compact)
        .onAppear {
            ttsViewModel.onChapterFinished = { [ttsViewModel] in
                ttsViewModel.goToNextChapter(forcePlay: true)
            }
        }
    }

    private func downloadDefaultVersionsIfNeeded() async {
        let bibleFileRepository = DIContainer.shared.resolve(type: BibleFileRepository.self)
        let bibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)
        let bibleDatabaseService = DIContainer.shared.resolve(type: BibleDatabaseService.self)

        // Delayed loading indicator - only shows after 200ms if still working
        let showLoadingAfterDelayTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled {
                showLoadingView = true
            }
        }

        // Check which versions need to be downloaded
        var versionsToDownload: [BibleVersion] = []

        do {
            let allVersions = try await bibleRepository.fetchBibleVersionList()

            // Default versions
            for versionCode in defaultVersions {
                if let version = allVersions.first(where: { $0.versionCode == versionCode }),
                   !version.isDownloaded {
                    versionsToDownload.append(version)
                }
            }

            // Versions removed due to schema update (need re-download)
            for versionCode in bibleDatabaseService.removedVersionCodes {
                if let version = allVersions.first(where: { $0.versionCode == versionCode }),
                   !versionsToDownload.contains(where: { $0.versionCode == versionCode }) {
                    versionsToDownload.append(version)
                }
            }
        } catch {
            Logger.repository.error("Failed to fetch version list: \(error.localizedDescription)")
            showLoadingAfterDelayTask.cancel()
            return
        }

        // Skip if no downloads are needed
        if versionsToDownload.isEmpty {
            showLoadingAfterDelayTask.cancel()
            appState.initialDownloadCompleted = true
            return
        }

        // Download versions
        for (index, version) in versionsToDownload.enumerated() {
            downloadProgress = "Downloading \(version.versionName)... (\(index + 1)/\(versionsToDownload.count))"

            do {
                try await bibleFileRepository.downloadAndInstall(version: version)
            } catch {
                Logger.repository.error("Failed to download \(version.versionCode): \(error.localizedDescription)")
            }
        }

        showLoadingAfterDelayTask.cancel()
        showLoadingView = false

        // 다운로드 완료 후 BibleReaderView 리로드 트리거
        appState.initialDownloadCompleted = true
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

    @ViewBuilder
    func applyTTSBottomAccessory(ttsViewModel: TTSViewModel, showFullPlayer: Binding<Bool>) -> some View {
        if #available(iOS 26.0, *) {
            if ttsViewModel.playbackState != .idle {
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
