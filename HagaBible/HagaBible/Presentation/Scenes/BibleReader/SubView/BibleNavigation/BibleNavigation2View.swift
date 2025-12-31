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
    
    @State var showVersionManageView: Bool = false
    @State var showDownloadConfirmation: Bool = false
    @State var pendingDownloadVersion: BibleVersion?
    @State var isDownloading: Bool = false

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
                        itemAlignment: .leading,
                        doubleTapAction: {
                            if let selectedVersion = selectedVersion, let selectedBook = selectedBook {
                                bibleReaderViewModel.applyBibleSelection(
                                    versionCode: selectedVersion.versionCode,
                                    bookCode: selectedBook.bookCode,
                                    chapterNum: 1,
                                    verseNum: 1
                                )
                                
                                dismiss()
                                
                                bibleReaderViewModel.navigatedVerseNum = 1
                                bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
                            }
                        }
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
                        },
                        doubleTapAction: {
                            if let selectedVersion = selectedVersion, let selectedBook = selectedBook, let selectedChapter = selectedChapter {
                                bibleReaderViewModel.applyBibleSelection(
                                    versionCode: selectedVersion.versionCode,
                                    bookCode: selectedBook.bookCode,
                                    chapterNum: selectedChapter.chapter,
                                    verseNum: 1
                                )
                                
                                dismiss()
                                
                                bibleReaderViewModel.navigatedVerseNum = 1
                                bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
                            }
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
            .onChange(of: selectedVersion) { oldValue, newValue in
                guard let newVersion = newValue else { return }

                if newVersion.isDownloaded == false {
                    // Download required - show confirmation popup
                    pendingDownloadVersion = newVersion
                    showDownloadConfirmation = true
                    // Revert to previous version until download is confirmed
                    selectedVersion = oldValue
                } else {
                    // Already downloaded - load immediately
                    Task {
                        await viewModel.loadBookList(version: newVersion)
                        selectedBook = nil
                    }
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
                        HStack {
                            Text(version.versionName)
                            if version.isDownloaded == false {
                                Image(systemName: "square.and.arrow.down")
                            }
                        }
                        .tag(version)
                    }
                }
                Button {
                    showVersionManageView = true
                } label: {
                    Label("Manage Versions", systemImage: "books.vertical")
                }
            }
            .sheet(isPresented: $showVersionManageView, onDismiss: {
                // Check if the currently selected version has been deleted
                if let current = selectedVersion {
                    let updatedVersion = viewModel.versionList.first { $0.versionCode == current.versionCode }
                    if updatedVersion == nil || updatedVersion?.isDownloaded == false {
                        // Deleted - switch to another downloaded version
                        selectedVersion = viewModel.versionList.first { $0.isDownloaded }
                        selectedBook = nil
                        selectedChapter = nil
                        selectedVerse = nil
                    }
                }
            }) {
                BibleVersionManageView()
                    .environment(viewModel)
            }
            .alert("Download Bible Version", isPresented: $showDownloadConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingDownloadVersion = nil
                }
                Button("Download") {
                    guard let version = pendingDownloadVersion else { return }
                    Task {
                        await downloadAndSelectVersion(version)
                    }
                }
            } message: {
                if let version = pendingDownloadVersion {
                    Text("\(version.versionName) is not downloaded yet. Download now?")
                }
            }
            .overlay {
                if isDownloading {
                    ProgressView("Downloading...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(selectedVersion?.versionName ?? "Version")
                }
            }
        }
    }

    private func downloadAndSelectVersion(_ version: BibleVersion) async {
        isDownloading = true
        defer {
            isDownloading = false
            pendingDownloadVersion = nil
        }

        do {
            let bibleFileRepository = DIContainer.shared.resolve(type: BibleFileRepository.self)
            try await bibleFileRepository.downloadAndInstall(version: version)

            // Refresh version list
            await viewModel.loadVersionList()

            // Select the updated version
            if let updatedVersion = viewModel.versionList.first(where: { $0.versionCode == version.versionCode }) {
                selectedVersion = updatedVersion
            }
        } catch {
            print("Failed to download bible: \(error)")
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
