//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var bibleReaderViewModel: BibleReaderViewModel
    
    @State private var viewModel: BibleNavigationViewModel = DIContainer.shared.resolve(type: BibleNavigationViewModel.self)
    
    @State var selectedVersion: BibleVersion?
    @State var selectedBook: BibleBook?
    @State var selectedChapter: BibleChapter?
    @State var selectedVerse: BibleVerse?
        
    var body: some View {
        NavigationStack {
            VStack {
                HStack(alignment: .top, spacing: 0) {
                    Picker("BookPicker", selection: $selectedBook) {
                        ForEach(viewModel.bookList, id: \.bookCode) { book in
                            Text(book.bookName).tag(book)
                        }
                    }
                    .pickerStyle(.wheel)
                    HStack(spacing: 0) {
                        Picker("ChapterPicker", selection: $selectedChapter) {
                            ForEach(viewModel.chapterList, id: \.self) { chapter in
                                Text("\(chapter.chapter)").tag(chapter)
                            }
                        }
                        .pickerStyle(.wheel)
                        Picker("VersePicker", selection: $selectedVerse) {
                            ForEach(viewModel.verseList, id: \.self) { verse in
                                Text("\(verse.verse)").tag(verse)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
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
                    selectedBook = viewModel.bookList.first(where: { $0.bookCode == selectedBook?.bookCode })
                }
            }
            .onChange(of: selectedBook) { oldValue, newValue in
                if oldValue?.bookCode == newValue?.bookCode {
                    selectedChapter = viewModel.chapterList.first(where: { $0.chapter == selectedChapter?.chapter })
                } else {
                    Task {
                        await viewModel.loadChapterList(version: selectedVersion!, book: selectedBook!)
                        selectedChapter = viewModel.chapterList.first
                    }
                }
            }
            .onChange(of: selectedChapter) { oldValue, newValue in
                if oldValue?.chapter == newValue?.chapter {
                    selectedVerse = viewModel.verseList.first(where: { $0.verse == selectedVerse?.verse })
                } else {
                    Task {
                        await viewModel.loadVerseList(version: selectedVersion!, book: selectedBook!, chapter: selectedChapter!)
                        selectedVerse = viewModel.verseList.first
                    }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        if selectedVersion == nil {
                            selectedVersion = viewModel.versionList.first!
                        }
                        if selectedBook == nil {
                            selectedBook = viewModel.bookList.first!
                        }
                        if selectedChapter == nil {
                            selectedChapter = viewModel.chapterList.first!
                        }
                        if selectedVerse == nil {
                            selectedVerse = viewModel.verseList.first!
                        }
                        
                        if let selectedVersion = selectedVersion {
                            bibleReaderViewModel.versionCode = selectedVersion.versionCode
                        }
                        if let selectedBook = selectedBook {
                            bibleReaderViewModel.bookCode = selectedBook.bookCode
                        }
                        if let selectedChapter = selectedChapter {
                            bibleReaderViewModel.chapterNum = selectedChapter.chapter
                        }
                        if let selectedVerse = selectedVerse {
                            bibleReaderViewModel.verseNum = selectedVerse.verse
                            bibleReaderViewModel.navigatedVerseNum = selectedVerse.verse
                        }
                        
                        dismiss()
                        if let selectedVerse = selectedVerse {
                            bibleReaderViewModel.navigatedVerseNum = selectedVerse.verse
                        } else {
                            bibleReaderViewModel.navigatedVerseNum = 1
                        }
                        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    let viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    return NavigationStack {
        Text("")
            .sheet(isPresented: .constant(true)) {
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
