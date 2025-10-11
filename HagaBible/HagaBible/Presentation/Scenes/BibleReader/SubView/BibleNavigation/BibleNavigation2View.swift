////
////  BibleNavigationView.swift
////  HagaBible
////
////  Created by 양시준 on 7/8/25.
////
//
//import SwiftUI
//
//struct BibleNavigation2View: View {
//    @Environment(\.dismiss) var dismiss
//    @Environment(BibleReaderViewModel.self) private var viewModel: BibleReaderViewModel
//    
//    @State var selectedVersion: BibleVersion?
//    @State var selectedBook: BibleBook?
//    @State var selectedChapter: BibleChapter?
//    @State var selectedVerse: BibleVerse?
//    
//    var body: some View {
//        NavigationStack {
//            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
//                GridRow {
//                    BibleNavigationColumnView(
//                        columnTitle: "Book",
//                        itemList: (selectedVersion != nil) ? viewModel.getBibleBookListByVersion(of: selectedVersion!) : [],
//                        selectedItem: $selectedBook,
//                        getDesciption: { $0.bookName },
//                        columnTitleAlignment: .leading,
//                        itemAlignment: .leading
//                    )
//                    .gridCellColumns(2)
//                    BibleNavigationColumnView(
//                        columnTitle: "Chapter",
//                        itemList: (selectedBook != nil) ? viewModel.getBibleChapterListByBook(of: selectedBook!) : [],
//                        selectedItem: $selectedChapter,
//                        getDesciption: { "\($0.chapter) 장" }
//                    )
//                    BibleNavigationColumnView(
//                        columnTitle: "Verse",
//                        itemList: (selectedChapter != nil) ? viewModel.getBibleVerseListByChapter(of: selectedChapter!) : [],
//                        selectedItem: $selectedVerse,
//                        getDesciption: { "\($0.verse) 절" }
//                    )
//                }
//                .scrollIndicators(.hidden)
//                .navigationBarTitleDisplayMode(.inline)
//            }
//            .toolbarTitleMenu {
//                Picker(selection: $selectedVersion, label: Text("Sorting options")) {
//                    ForEach(viewModel.availableVersions, id: \.versionCode) { version in
//                        Text(version.versionName).tag(version)
//                    }
//                }
//            }
//            .toolbar {
//                ToolbarItem(placement: .title) {
//                    Text(viewModel.bibleVersion?.versionName ?? "Version")
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button(action: {
//                        if selectedVersion == nil {
//                            selectedVersion = viewModel.availableVersions.first!
//                        }
//                        if selectedBook == nil {
//                            selectedBook = viewModel.bibleBookList.first!
//                        }
//                        if selectedChapter == nil {
//                            selectedChapter = viewModel.getBibleChapterListByBook(of: selectedBook!).first!
//                        }
//                        if selectedVerse == nil {
//                            selectedVerse = viewModel.getBibleVerseListByChapter(of: selectedChapter!).first!
//                        }
//                        
//                        if let selectedVersion = selectedVersion {
//                            viewModel.versionCode = selectedVersion.versionCode
//                        }
//                        if let selectedBook = selectedBook {
//                            viewModel.bookCode = selectedBook.bookCode
//                        }
//                        if let selectedChapter = selectedChapter {
//                            viewModel.chapterNum = selectedChapter.chapter
//                        }
//                        if let selectedVerse = selectedVerse {
//                            viewModel.navigatedVerseNum = selectedVerse.verse
//                        }
//                        
//                        dismiss()
//                        if let selectedVerse = selectedVerse {
//                            viewModel.navigatedVerseNum = selectedVerse.verse
//                        } else {
//                            viewModel.navigatedVerseNum = 1
//                        }
//                        viewModel.bibleNavigationUpdateTrigger.toggle()
//                    }) {
//                        Image(systemName: "checkmark")
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .tint(.orange)
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    @Previewable @State var isPresented: Bool = false
//    @Previewable @State var viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
//    
//    NavigationStack {
//        Button(action: { isPresented.toggle() }) {
//            Text("present")
//        }
//        .sheet(isPresented: $isPresented) {
//            BibleNavigation2View()
//                .environment(viewModel)
//                .presentationDetents([.small])
//        }
//    }
//}
