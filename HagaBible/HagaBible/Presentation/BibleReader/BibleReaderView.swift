//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @Bindable private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)

    @State private var currentChapterIndex = 0
    @State private var dragOffset: CGSize = .zero
    
    private func handleSwipe(_ gesture: DragGesture.Value) {
        let swipeThreshold: CGFloat = 50

        if abs(gesture.predictedEndTranslation.width) > swipeThreshold {
            if gesture.predictedEndTranslation.width > 0 {
                viewModel.getPrevChapter()
            } else if gesture.predictedEndTranslation.width < 0 {
                viewModel.getNextChapter()
            }
        }
        
        self.dragOffset = .zero
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea(.all)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id("topAnchor")
                            Group {
                                if let verses = viewModel.verses {
                                    VStack(spacing: 0) {
                                        Color.clear
                                            .frame(height: 0)
                                            .background(
                                                GeometryReader { geometry in
                                                    Color.clear.preference(
                                                        key: ScrollOffsetPreferenceKey.self,
                                                        value: geometry.frame(in: .named("scroll")).minY
                                                    )
                                                }
                                            )
                                        ForEach(0..<verses.count, id: \.self) { index in
                                            BibleVerseView(
                                                verseNumber: index + 1,
                                                verseText: verses[index].text
                                            )
                                            .padding(.vertical, 8)
                                        }
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 16)
                                } else {
                                    Text("Loading...")
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.chapterNum, initial: false) {
                        proxy.scrollTo("topAnchor", anchor: .top)
                    }
                }
                .navigationTitleButton(title: "\(viewModel.bookName ?? "") \(viewModel.chapterNum)", subtitle: "\(viewModel.version?.name ?? "")")
                .background(Color.white)
                .offset(x: self.dragOffset.width)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                self.dragOffset = gesture.translation
                            } else {
                                self.dragOffset = .zero
                            }
                        }
                        .onEnded { gesture in
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                handleSwipe(gesture)
                            } else {
                                self.dragOffset = .zero
                            }
                        }
                )
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button(action: {}) {
                        Image(systemName: "headphones")
                    }
                }
                ToolbarSpacer(.fixed)
                ToolbarItem {
                    Menu {
                        Menu {
//                                Picker(selection: $selectedVersion, label: Text("Sorting options")) {
//                                    Text("WEBBE").tag("WEBBE")
//                                    Text("KJV").tag("KJV")
//                                    Text("NIV").tag("NIV")
//                                }
                        } label: {
                            Label("Versions", systemImage: "books.vertical")
                        }
                        Button(action: {}) {
                            Label("Bookmarks", systemImage: "bookmark")
                        }
                        Button(action: {}) {
                            Label("Font & Themes", systemImage: "textformat.size")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .task {
            await viewModel.fetchAvailableVersions()
            viewModel.selectVersion(versionId: "WEBBE")
            await viewModel.fetchBibleContent(versionId: "WEBBE")
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}
