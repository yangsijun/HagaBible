//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @State private var showBibleNavigation: Bool = false
    @State private var isDraggingHorizontally = false
    @State private var highlightTask: Task<Void, Error>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea(.all)
                ScrollViewReader { proxy in
                    ScrollView {
                        Group {
                            if viewModel.bibleVersion?.language == "English" {
                                BibleVerseListView(
                                    verses: viewModel.bibleVerseList,
                                    fontConfiguration: viewModel.fontConfiguration,
                                    highlightedVerseNum: viewModel.navigatedVerseNum
                                )
                            } else {
                                BibleVerseListView(
                                    verses: viewModel.bibleVerseList,
                                    fontConfiguration: viewModel.fontConfigurationKorean,
                                    highlightedVerseNum: viewModel.navigatedVerseNum
                                )
                            }
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
                    }
                    .background(Color(uiColor: .systemBackground))
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
                    showBibleNavigation: $showBibleNavigation
                )
            }
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
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}
