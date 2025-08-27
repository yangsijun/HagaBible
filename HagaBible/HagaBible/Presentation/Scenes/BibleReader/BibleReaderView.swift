//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @State private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    @State private var showBibleNavigation: Bool = false
    @State private var showFontThemeConfig: Bool = false
    @State private var isDraggingHorizontally = false
    @State private var highlightTask: Task<Void, Error>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea(.all)
                ScrollViewReader { proxy in
                    ScrollView {
                        BibleVerseListView(
                            verses: viewModel.bibleVerseList,
                            language: viewModel.bibleVersion?.language ?? "English",
                            fontConfiguration: fontThemeManager.fontConfiguration,
                            theme: fontThemeManager.theme,
                            highlightedVerseNum: viewModel.navigatedVerseNum
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
                    }
                    .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
                    .swipeGesture(
                        onLeftSwipe: {
                            viewModel.goToPreviousChapter()
                            viewModel.bibleNavigationUpdateTrigger.toggle()
                        },
                        onRightSwipe: {
                            viewModel.goToNextChapter()
                            viewModel.bibleNavigationUpdateTrigger.toggle()
                        }
                    )
                    .onChange(of: viewModel.bibleNavigationUpdateTrigger, initial: false) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.linear(duration: 0.3)) {
                                proxy.scrollTo((viewModel.navigatedVerseNum ?? 1) - 1, anchor: .top)
                            }
                        }
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                BibleReaderToolbarContent(
                    bookName: viewModel.bibleBook?.bookName,
                    chapterNum: viewModel.chapterNum,
                    bibleVersion: viewModel.bibleVersion,
                    showBibleNavigation: $showBibleNavigation,
                    showFontThemeConfig: $showFontThemeConfig
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBibleNavigation) {
                BibleNavigationView(
                    selectedVersion: viewModel.bibleVersion,
                    selectedBook: viewModel.bibleBook,
                    selectedChapter: viewModel.bibleChapter,
                    selectedVerse: viewModel.bibleVerse,
                )
                    .environment(viewModel)
                    .presentationDetents([.small])
            }
            .sheet(isPresented: $showFontThemeConfig) {
                FontThemeConfigView(language: viewModel.bibleVersion?.language ?? "English")
                    .environment(fontThemeManager)
                    .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}
