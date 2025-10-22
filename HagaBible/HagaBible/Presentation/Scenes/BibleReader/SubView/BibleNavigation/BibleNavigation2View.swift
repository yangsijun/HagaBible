//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigation2View: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var bibleReaderViewModel: BibleReaderViewModel
    
    @State private var viewModel: BibleNavigationViewModel = DIContainer.shared.resolve(type: BibleNavigationViewModel.self)
    
    @State var selectedVersion: BibleVersion?
    @State var selectedBook: BibleBook?
    @State var selectedChapter: BibleChapter?
    @State var selectedVerse: BibleVerse?
    
    var body: some View {
        NavigationStack {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    BibleNavigationColumnView(
                        columnTitle: "Book",
                        itemList: (selectedVersion != nil) ? viewModel.bookList: [],
                        selectedItem: $selectedBook,
                        getDesciption: { $0.bookName },
                        columnTitleAlignment: .leading,
                        itemAlignment: .leading
                    )
                    .gridCellColumns(2)
                    BibleNavigationColumnView(
                        columnTitle: "Chapter",
                        itemList: (selectedBook != nil) ? viewModel.chapterList : [],
                        selectedItem: $selectedChapter,
                        getDesciption: {
                            let counterNoun: String = getChapterCounterNoun(bookCode: selectedBook?.bookCode ?? "", versionLanguage: selectedVersion?.language ?? "English")
                            if !counterNoun.isEmpty {
                                return "\($0.chapter) \(counterNoun)"
                            }
                            return "\($0.chapter)"
                        }
                    )
                    BibleNavigationColumnView(
                        columnTitle: "Verse",
                        itemList: (selectedChapter != nil) ? viewModel.verseList : [],
                        selectedItem: $selectedVerse,
                        getDesciption: {
                            let counterNoun: String = getVerseCounterNoun(versionLanguage: selectedVersion?.language ?? "English")
                            if !counterNoun.isEmpty {
                                return "\($0.verse) \(counterNoun)"
                            }
                            return "\($0.verse)"
                        }
                    )
                }
                .scrollIndicators(.hidden)
                .navigationBarTitleDisplayMode(.inline)
            }
            .task {
                await viewModel.loadVersionList()
                if let selectedVersion = selectedVersion {
                    await viewModel.loadBookList(version: selectedVersion)
                    if let selectedBook = selectedBook {
                        await viewModel.loadChapterList(version: selectedVersion, book: selectedBook)
                        if let selectedChapter = selectedChapter {
                            await viewModel.loadVerseList(version: selectedVersion, book: selectedBook, chapter: selectedChapter)
                        }
                    }
                }
            }
            .onChange(of: selectedVersion) {
                Task {
                    await viewModel.loadBookList(version: selectedVersion!)
                    selectedBook = nil
                }
            }
            .onChange(of: selectedBook) { oldValue, newValue in
                if newValue == nil {
                    selectedChapter = nil
                    selectedVerse = nil
                    return
                }
                if oldValue?.bookCode == newValue?.bookCode {
                    selectedChapter = viewModel.chapterList.first(where: { $0.chapter == selectedChapter?.chapter })
                } else {
                    Task {
                        await viewModel.loadChapterList(version: selectedVersion!, book: selectedBook!)
                        selectedChapter = nil
                    }
                }
            }
            .onChange(of: selectedChapter) { oldValue, newValue in
                if newValue == nil {
                    selectedVerse = nil
                    return
                }
                if oldValue?.chapter == newValue?.chapter {
                    selectedVerse = viewModel.verseList.first(where: { $0.verse == selectedVerse?.verse })
                } else {
                    Task {
                        await viewModel.loadVerseList(version: selectedVersion!, book: selectedBook!, chapter: selectedChapter!)
                        selectedVerse = nil
                    }
                }
            }
            .onChange(of: selectedVerse) { oldValue, newValue in
                if newValue == nil {
                    return
                }
                Task {
                    bibleReaderViewModel.applyBibleSelection(
                        versionCode: selectedVersion?.versionCode,
                        bookCode: selectedBook?.bookCode,
                        chapterNum: selectedChapter?.chapter,
                        verseNum: selectedVerse?.verse
                    )
                    
                    dismiss()
                    if let selectedVerse = selectedVerse {
                        bibleReaderViewModel.navigatedVerseNum = selectedVerse.verse
                    } else {
                        bibleReaderViewModel.navigatedVerseNum = 1
                    }
                    bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
                }
            }
            .toolbarTitleMenu {
                Picker(selection: $selectedVersion, label: Text("Sorting options")) {
                    ForEach(viewModel.versionList, id: \.versionCode) { version in
                        Text(version.versionName).tag(version)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(selectedVersion?.versionName ?? "Version")
                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button(action: {
//                        if selectedVersion == nil {
//                            selectedVersion = viewModel.versionList.first!
//                        }
//                        if selectedBook == nil {
//                            selectedBook = viewModel.bookList.first!
//                        }
//                        if selectedChapter == nil {
//                            selectedChapter = viewModel.chapterList.first!
//                        }
//                        if selectedVerse == nil {
//                            selectedVerse = viewModel.verseList.first!
//                        }
//                        
//                        bibleReaderViewModel.applyBibleSelection(
//                            versionCode: selectedVersion?.versionCode,
//                            bookCode: selectedBook?.bookCode,
//                            chapterNum: selectedChapter?.chapter,
//                            verseNum: selectedVerse?.verse
//                        )
//                        
//                        dismiss()
//                        if let selectedVerse = selectedVerse {
//                            bibleReaderViewModel.navigatedVerseNum = selectedVerse.verse
//                        } else {
//                            bibleReaderViewModel.navigatedVerseNum = 1
//                        }
//                        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
//                    }) {
//                        Image(systemName: "checkmark")
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .tint(.orange)
//                }
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
}
