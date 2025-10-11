//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var bibleReadeViewModel: BibleReaderViewModel
    
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
                await viewModel.loadBookList(version: selectedVersion!)
                await viewModel.loadChapterList(version: selectedVersion!, book: selectedBook!)
                await viewModel.loadVerseList(version: selectedVersion!, book: selectedBook!, chapter: selectedChapter!)
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
                    selectedChapter = viewModel.chapterList.first
                }
            }
            .onChange(of: selectedChapter) { oldValue, newValue in
                if oldValue?.chapter == newValue?.chapter {
                    selectedVerse = viewModel.verseList.first(where: { $0.verse == selectedVerse?.verse })
                } else {
                    selectedVerse = viewModel.verseList.first
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
                            bibleReadeViewModel.versionCode = selectedVersion.versionCode
                        }
                        if let selectedBook = selectedBook {
                            bibleReadeViewModel.bookCode = selectedBook.bookCode
                        }
                        if let selectedChapter = selectedChapter {
                            bibleReadeViewModel.chapterNum = selectedChapter.chapter
                        }
                        if let selectedVerse = selectedVerse {
                            bibleReadeViewModel.verseNum = selectedVerse.verse
                            bibleReadeViewModel.navigatedVerseNum = selectedVerse.verse
                        }
                        
                        dismiss()
                        if let selectedVerse = selectedVerse {
                            bibleReadeViewModel.navigatedVerseNum = selectedVerse.verse
                        } else {
                            bibleReadeViewModel.navigatedVerseNum = 1
                        }
                        bibleReadeViewModel.bibleNavigationUpdateTrigger.toggle()
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
    @Previewable @State var isPresented: Bool = false
    @Previewable @State var viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    NavigationStack {
        Button(action: { isPresented.toggle() }) {
            Text("present")
        }
        .sheet(isPresented: $isPresented) {
            BibleNavigationView()
                .environment(viewModel)
                .presentationDetents([.small])
        }
    }
}
