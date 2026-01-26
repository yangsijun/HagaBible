//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @State private var appState: AppState = DIContainer.shared.resolve(type: AppState.self)
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @State private var showBibleNavigation: Bool = false
    @State private var showFontThemeConfig: Bool = false
    @State private var isDraggingHorizontally = false
    @State private var highlightTask: Task<Void, Error>?
    @State private var ttsViewModel: TTSViewModel = DIContainer.shared.resolve(type: TTSViewModel.self)

    @State var selectStartIndex: Int?
    @State var selectEndIndex: Int?
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    BibleVerseListView(
                        verses: viewModel.bibleVerseList,
                        language: viewModel.bibleVersion?.language ?? "English",
                        fontConfiguration: fontThemeManager.fontConfiguration,
                        theme: fontThemeManager.theme,
                        highlightedVerseNum: viewModel.navigatedVerseNum,
                        ttsCurrentVerseIndex: ttsViewModel.playbackState != .idle ? ttsViewModel.currentVerseIndex : nil,
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
                .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
                .swipeGesture(
                    onLeftSwipe: {
                        let wasActive = ttsViewModel.playbackState != .idle
                        viewModel.goToPreviousChapter()
                        viewModel.bibleNavigationUpdateTrigger.toggle()
                        if wasActive {
                            Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                let language = viewModel.bibleVersion?.language ?? "Korean"
                                ttsViewModel.switchChapter(verses: viewModel.bibleVerseList, language: language)
                            }
                        }
                    },
                    onRightSwipe: {
                        let wasActive = ttsViewModel.playbackState != .idle
                        viewModel.goToNextChapter()
                        viewModel.bibleNavigationUpdateTrigger.toggle()
                        if wasActive {
                            Task {
                                try? await Task.sleep(for: .milliseconds(100))
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
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                BibleReaderActionBar(
                    selectStartIndex: $selectStartIndex,
                    selectEndIndex: $selectEndIndex,
                    bibleVerseList: viewModel.bibleVerseList
                )
                .ignoresSafeArea(edges: .horizontal)
            }
            .toolbar {
                BibleReaderToolbarContent(
                    bibleBook: viewModel.bibleBook,
                    chapterNum: viewModel.chapterNum,
                    bibleVersion: viewModel.bibleVersion,
                    showBibleNavigation: $showBibleNavigation,
                    showFontThemeConfig: $showFontThemeConfig,
                    onListenTapped: handleListenTapped,
                    ttsPlaybackState: ttsViewModel.playbackState
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
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
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
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - TTS Methods
    private func handleListenTapped() {
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
