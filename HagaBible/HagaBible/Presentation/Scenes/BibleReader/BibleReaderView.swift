//
//  BibleReaderView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea(.all)
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear
                            .frame(height: 0)
                            .id("topAnchor")
                        BibleVerseListView(verses: viewModel.verses, fontConfiguration: viewModel.fontConfiguration)
                    }
                    .background(Color.white)
                    .swipeGesture(onLeftSwipe: viewModel.getPrevChapter, onRightSwipe: viewModel.getNextChapter)
                    .onChange(of: viewModel.chapterNum, initial: false) {
                        proxy.scrollTo("topAnchor", anchor: .top)
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                BibleReaderToolbarContent(
                    bookName: viewModel.bookName,
                    chapterNum: viewModel.chapterNum,
                    version: viewModel.version
                )
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
