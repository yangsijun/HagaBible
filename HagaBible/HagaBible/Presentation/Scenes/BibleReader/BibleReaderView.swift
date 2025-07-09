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
                        BibleVerseListView(
                            verses: viewModel.verses,
                            fontConfiguration: viewModel.fontConfiguration,
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
                    .disabled(isDraggingHorizontally)
                    .background(Color(uiColor: .systemBackground))
                    .swipeGesture(
                        isDraggingHorizontally: $isDraggingHorizontally,
                        onLeftSwipe: {
                            viewModel.getPrevChapter()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.linear(duration: 0.3)) {
                                    proxy.scrollTo(0, anchor: .top)
                                }
                            }
                        },
                        onRightSwipe: {
                            viewModel.getNextChapter()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.linear(duration: 0.3)) {
                                    proxy.scrollTo(0, anchor: .top)
                                }
                            }
                        }
                    )
                    .onChange(of: viewModel.bibleNavigationUpdateTrigger, initial: false) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.linear(duration: 0.3)) {
                                proxy.scrollTo((viewModel.verseNum ?? 1) - 1, anchor: .top)
                            }
                        }
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                BibleReaderToolbarContent(
                    bookName: viewModel.bookName,
                    chapterNum: viewModel.chapterNum,
                    version: viewModel.version,
                    showBibleNavigation: $showBibleNavigation
                )
            }
            .sheet(isPresented: $showBibleNavigation) {
                BibleNavigation2View(
                    selectedBook: viewModel.book,
                    selectedChapter: viewModel.chapter
                )
                    .environment(viewModel)
                    .presentationDetents([.small])
            }
        }
        .task {
            await viewModel.fetchAvailableVersions()
            await viewModel.selectVersion(versionId: "WEBBE")
            await viewModel.fetchBibleContent(versionId: "WEBBE")
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}
