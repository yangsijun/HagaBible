//
//  BibleNavigationView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import OSLog
import SwiftUI

struct BibleNavigation2View: View {
    @Environment(\.dismiss) var dismiss
    @Environment(BibleReaderViewModel.self) private var bibleReaderViewModel: BibleReaderViewModel

    @State private var viewModel: BibleNavigationViewModel = DIContainer.shared.resolve(type: BibleNavigationViewModel.self)
    @State private var ttsViewModel: TTSViewModel = DIContainer.shared.resolve(type: TTSViewModel.self)
    
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
                                switchTTSChapterIfActive(language: selectedVersion.language)
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
                                switchTTSChapterIfActive(language: selectedVersion.language)
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
                        },
                        additionalAction: {
                            if let verse = selectedVerse {
                                confirmVerseSelection(verse)
                            }
                        },
                        doubleTapAction: {
                            if let verse = selectedVerse {
                                confirmVerseSelection(verse)
                            }
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
                    // Already downloaded - keep the current book/chapter/verse
                    // selection, re-resolved against the new version. Setting
                    // selectedBook to the matching book triggers the cascade
                    // below, which re-resolves chapter and verse in turn.
                    let previousBookCode = selectedBook?.bookCode
                    Task {
                        await viewModel.loadBookList(version: newVersion)
                        // Bail out if the user switched versions again while loading.
                        guard selectedVersion?.versionCode == newVersion.versionCode else { return }
                        if let previousBookCode {
                            selectedBook = viewModel.bookList.first(where: { $0.bookCode == previousBookCode })
                                ?? viewModel.bookList.first
                        } else {
                            selectedBook = nil
                        }
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
                    // Same book in a different version (version switch): reload
                    // the chapter list for the new version and keep the chapter.
                    let previousChapterNum = selectedChapter?.chapter
                    Task {
                        await viewModel.loadChapterList(version: selectedVersion!, book: newValue!)
                        if let previousChapterNum {
                            // Keep the same chapter; if the new version omits it,
                            // fall back to the nearest preceding chapter, then the
                            // first. chapterList is ascending by chapter.
                            selectedChapter = viewModel.chapterList.first(where: { $0.chapter == previousChapterNum })
                                ?? viewModel.chapterList.last(where: { $0.chapter < previousChapterNum })
                                ?? viewModel.chapterList.first
                        } else {
                            selectedChapter = nil
                        }
                    }
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
                    // Same chapter in a different version (version switch): reload
                    // the verse list for the new version and keep the verse.
                    let previousVerseNum = selectedVerse?.verse
                    Task {
                        await viewModel.loadVerseList(version: selectedVersion!, book: selectedBook!, chapter: newValue!)
                        if let previousVerseNum {
                            // Keep the same verse; if the new version omits it
                            // (versification differences), fall back to the nearest
                            // preceding verse, then the first verse. verseList is
                            // ascending by verse, so last(where: < n) is the closest
                            // verse at or before the previous one.
                            selectedVerse = viewModel.verseList.first(where: { $0.verse == previousVerseNum })
                                ?? viewModel.verseList.last(where: { $0.verse < previousVerseNum })
                                ?? viewModel.verseList.first
                        } else {
                            selectedVerse = nil
                        }
                    }
                } else {
                    Task {
                        await viewModel.loadVerseList(version: selectedVersion!, book: selectedBook!, chapter: selectedChapter!)
                        selectedVerse = nil
                    }
                }
            }
            .toolbarTitleMenu {
                ForEach(viewModel.versionList, id: \.versionCode) { version in
                    Button {
                        selectedVersion = version
                    } label: {
                        HStack {
                            Text(version.versionName)
                            if version.isDownloaded == false {
                                Image(systemName: "square.and.arrow.down")
                            }
                            if version.versionCode == selectedVersion?.versionCode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
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

    /// Applies the chosen verse to the reader and dismisses the navigation
    /// sheet. Invoked by an explicit tap on a verse so that programmatic verse
    /// re-resolution (e.g. when switching versions) does not auto-navigate.
    private func confirmVerseSelection(_ verse: BibleVerse) {
        bibleReaderViewModel.applyBibleSelection(
            versionCode: selectedVersion?.versionCode,
            bookCode: selectedBook?.bookCode,
            chapterNum: selectedChapter?.chapter,
            verseNum: verse.verse
        )

        dismiss()

        bibleReaderViewModel.navigatedVerseNum = verse.verse
        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
        switchTTSChapterIfActive(language: selectedVersion?.language ?? "Korean", startVerseNum: verse.verse)
    }

    private func switchTTSChapterIfActive(language: String, startVerseNum: Int = 1) {
        guard ttsViewModel.playbackState != .idle else { return }

        let oldVerses = bibleReaderViewModel.bibleVerseList

        Task {
            // verses가 실제로 변경될 때까지 대기 (최대 2초)
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(100))
                if bibleReaderViewModel.bibleVerseList != oldVerses {
                    break
                }
            }

            let startIndex = max(0, startVerseNum - 1)
            ttsViewModel.switchChapter(verses: bibleReaderViewModel.bibleVerseList, language: language, forcePlay: true, startIndex: startIndex)
        }
    }

    private func downloadAndSelectVersion(_ version: BibleVersion) async {
        isDownloading = true
        defer {
            isDownloading = false
            pendingDownloadVersion = nil
        }

        do {
            // Route through the acquire use case so paid versions trigger the
            // purchase flow (and entitlement check) before downloading — never
            // download a paid version directly.
            let acquireUseCase = DIContainer.shared.resolve(type: AcquireBibleVersionUseCase.self)
            let outcome = try await acquireUseCase.execute(version: version)

            // Only select when the version was actually installed; a cancelled or
            // pending purchase leaves the previous selection intact.
            guard outcome == .installed else { return }

            // Refresh version list
            await viewModel.loadVersionList()

            // Select the updated version
            if let updatedVersion = viewModel.versionList.first(where: { $0.versionCode == version.versionCode }) {
                selectedVersion = updatedVersion
            }
        } catch {
            Logger.repository.error("Failed to download bible: \(error.localizedDescription)")
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
