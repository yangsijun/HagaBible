//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var viewModel: BibleReaderViewModel
    
    @State var selectedVersion: BibleVersion?
    @State var selectedBook: BibleBook?
    @State var selectedChapter: BibleChapter?
    @State var selectedVerse: BibleVerse?
    
    var pickerVersionList: [BibleVersion] {
        viewModel.availableVersions
    }
    var pickerBookList: [BibleBook] {
        viewModel.getBibleBookListByVersion(of: selectedVersion ?? pickerVersionList.first!)
    }
    var pickerChapterList: [BibleChapter] {
        viewModel.getBibleChapterListByBook(of: selectedBook ?? pickerBookList.first!)
    }
    var pickerVerseList: [BibleVerse] {
        viewModel.getBibleVerseListByChapter(of: selectedChapter ?? pickerChapterList.first!)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack(alignment: .top, spacing: 0) {
                    Picker("BookPicker", selection: $selectedBook) {
                        ForEach(pickerBookList, id: \.bookCode) { book in
                            Text(book.bookName).tag(book)
                        }
                    }
                    .pickerStyle(.wheel)
                    HStack(spacing: 0) {
                        Picker("ChapterPicker", selection: $selectedChapter) {
                            ForEach(pickerChapterList, id: \.self) { chapter in
                                Text("\(chapter.chapter)").tag(chapter)
                            }
                        }
                        .pickerStyle(.wheel)
                        Picker("VersePicker", selection: $selectedVerse) {
                            ForEach(pickerVerseList, id: \.self) { verse in
                                Text("\(verse.verse)").tag(verse)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .onChange(of: selectedVersion) {
                selectedBook = pickerBookList.first(where: { $0.bookCode == selectedBook?.bookCode })
            }
            .onChange(of: selectedBook) { oldValue, newValue in
                if oldValue?.bookCode == newValue?.bookCode {
                    selectedChapter = pickerChapterList.first(where: { $0.chapter == selectedChapter?.chapter })
                } else {
                    selectedChapter = pickerChapterList.first
                }
            }
            .onChange(of: selectedChapter) { oldValue, newValue in
                if oldValue?.chapter == newValue?.chapter {
                    selectedVerse = pickerVerseList.first(where: { $0.verse == selectedVerse?.verse })
                } else {
                    selectedVerse = pickerVerseList.first
                }
            }
            .toolbarTitleMenu {
                Picker(selection: $selectedVersion, label: Text("Sorting options")) {
                    ForEach(viewModel.availableVersions, id: \.versionCode) { version in
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
                            selectedVersion = viewModel.availableVersions.first!
                        }
                        if selectedBook == nil {
                            selectedBook = viewModel.bibleBookList.first!
                        }
                        if selectedChapter == nil {
                            selectedChapter = viewModel.getBibleChapterListByBook(of: selectedBook!).first!
                        }
                        if selectedVerse == nil {
                            selectedVerse = viewModel.getBibleVerseListByChapter(of: selectedChapter!).first!
                        }
                        
                        if let selectedVersion = selectedVersion {
                            viewModel.versionCode = selectedVersion.versionCode
                        }
                        if let selectedBook = selectedBook {
                            viewModel.bookCode = selectedBook.bookCode
                        }
                        if let selectedChapter = selectedChapter {
                            viewModel.chapterNum = selectedChapter.chapter
                        }
                        if let selectedVerse = selectedVerse {
                            viewModel.verseNum = selectedVerse.verse
                            viewModel.navigatedVerseNum = selectedVerse.verse
                        }
                        
                        dismiss()
                        if let selectedVerse = selectedVerse {
                            viewModel.navigatedVerseNum = selectedVerse.verse
                        } else {
                            viewModel.navigatedVerseNum = 1
                        }
                        viewModel.bibleNavigationUpdateTrigger.toggle()
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
