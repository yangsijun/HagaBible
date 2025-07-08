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
    
    @State private var selectedBook: Book?
    @State private var selectedChapter: Chapter?
    @State private var selectedVerse: Verse? = nil
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if let books = viewModel.books {
                            ForEach(books) { book in
                                BibleNavigationButton(
                                    label: {
                                        HStack {
                                            Text(book.bookName)
                                                .font(.pretendard(size: 20))
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 8)
                                            Spacer()
                                        }
                                    },
                                    value: book,
                                    selection: $selectedBook
                                )
                                Divider()
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Divider()
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            if let chapters = selectedBook?.chapters {
                                ForEach(chapters) { chapter in
                                    BibleNavigationButton(
                                        label: {
                                            Text("\(chapter.chapter) 장")
                                                .font(.pretendard(size: 20))
                                                .padding(.vertical, 8)
                                        },
                                        value: chapter,
                                        selection: $selectedChapter
                                    )
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            if let verses = selectedChapter?.verses {
                                ForEach(verses) { verse in
                                    BibleNavigationButton(
                                        label: {
                                            Text("\(verse.verse) 절")
                                                .font(.pretendard(size: 20))
                                                .padding(.vertical, 8)
                                        },
                                        value: verse,
                                        selection: $selectedVerse,
                                        additionalAction: {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                viewModel.bibleNavigationUpdateTrigger.toggle()
                                                dismiss()
                                            }
                                        }
                                    )
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            selectedBook = viewModel.book
            selectedChapter = viewModel.chapter
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
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = false
    DIContainer.registerForPreview()
    let viewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    
    return NavigationStack {
        Button(action: { isPresented.toggle() }) {
            Text("present")
        }
        .sheet(isPresented: $isPresented) {
            BibleNavigationView()
                .environment(viewModel)
        }
    }
    .task {
        await viewModel.fetchAvailableVersions()
        viewModel.selectVersion(versionId: "WEBBE")
        await viewModel.fetchBibleContent(versionId: "WEBBE")
    }
}
