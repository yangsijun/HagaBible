//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigation2View: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var viewModel: BibleReaderViewModel
    
    @State private var selectedVersionId: String?
    @State var selectedBook: Book?
    @State var selectedChapter: Chapter?
    @State var selectedVerse: Verse?
    
    var body: some View {
        NavigationStack {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    BibleNavigationColumnView(
                        columnTitle: "Book",
                        itemList: viewModel.books ?? [],
                        selectedItem: $selectedBook,
                        getDesciption: { $0.bookName },
                        columnTitleAlignment: .leading,
                        itemAlignment: .leading
                    )
                    .gridCellColumns(2)
                    BibleNavigationColumnView(
                        columnTitle: "Chapter",
                        itemList: selectedBook?.chapters ?? [],
                        selectedItem: $selectedChapter,
                        getDesciption: { "\($0.chapter) 장" }
                    )
                    BibleNavigationColumnView(
                        columnTitle: "Verse",
                        itemList: selectedChapter?.verses ?? [],
                        selectedItem: $selectedVerse,
                        getDesciption: { "\($0.verse) 절" }
                    )
                }
                .scrollIndicators(.hidden)
                .navigationBarTitleDisplayMode(.inline)
            }
            .toolbarTitleMenu {
                Picker(selection: $selectedVersionId, label: Text("Sorting options")) {
                    ForEach(viewModel.availableVersions) { version in
                        Text(version.name).tag(version.id)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(viewModel.version?.name ?? "Version")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        dismiss()
                        viewModel.navigatedVerseNum = viewModel.verseNum
                        viewModel.bibleNavigationUpdateTrigger.toggle()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .onChange(of: selectedBook, initial: false) {
                if let book = selectedBook {
                    selectedChapter = book.chapters.first ?? nil
                }
            }
            .onChange(of: selectedChapter, initial: false) {
                if let chapter = selectedChapter {
                    selectedVerse = chapter.verses.first ?? nil
                }
            }
            .onChange(of: selectedVerse, initial: false) {
                if let verseNum = selectedVerse?.verse {
                    if let bookNum = selectedBook?.bookOrder {
                        viewModel.bookNum = bookNum
                    }
                    if let chapterNum = selectedChapter?.chapter {
                        viewModel.chapterNum = chapterNum
                    }
                    viewModel.verseNum = verseNum
                }
            }
            .task(id: selectedVersionId) {
                guard let versionId = selectedVersionId else { return }
                await viewModel.selectVersion(versionId: versionId)
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = false
    @Previewable @State var viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    NavigationStack {
        Button(action: { isPresented.toggle() }) {
            Text("present")
        }
        .sheet(isPresented: $isPresented) {
            BibleNavigation2View()
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
