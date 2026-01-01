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
    @State private var search: String = ""

    @State private var isInitializing: Bool = true
    @State private var downloadProgress: String = ""

    private let defaultVersions = ["WEBBE", "NKRV"]

    var body: some View {
        Group {
            if isInitializing {
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
        .environment(\.horizontalSizeClass, .compact)
    }

    private func downloadDefaultVersionsIfNeeded() async {
        let bibleFileRepository = DIContainer.shared.resolve(type: BibleFileRepository.self)
        let bibleRepository = DIContainer.shared.resolve(type: BibleRepository.self)

        // Check which versions need to be downloaded
        var versionsToDownload: [BibleVersion] = []

        do {
            let allVersions = try await bibleRepository.fetchBibleVersionList()

            for versionCode in defaultVersions {
                if let version = allVersions.first(where: { $0.versionCode == versionCode }),
                   !version.isDownloaded {
                    versionsToDownload.append(version)
                }
            }
        } catch {
            Logger.repository.error("Failed to fetch version list: \(error.localizedDescription)")
        }

        // Skip if no downloads are needed
        if versionsToDownload.isEmpty {
            isInitializing = false
            return
        }

        // Download default versions
        for (index, version) in versionsToDownload.enumerated() {
            downloadProgress = "Downloading \(version.versionName)... (\(index + 1)/\(versionsToDownload.count))"

            do {
                try await bibleFileRepository.downloadAndInstall(version: version)
            } catch {
                Logger.repository.error("Failed to download \(version.versionCode): \(error.localizedDescription)")
            }
        }

        isInitializing = false
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
}

#Preview {
    RootView()
}
