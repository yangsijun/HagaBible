//
//  SearchView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismissSearch) var dismissSearch
    
    @Binding var searchText: String
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    @State private var expandedBooks: Set<String> = []
    @State private var showClearSearchHistoryDialog = false
    
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    if searchText.isEmpty {
                        if !viewModel.searchHistories.isEmpty {
                            Section(header: Text("Search History")) {
                                ForEach(viewModel.searchHistories) { searchHistory in
                                    Button{
                                        viewModel.gotoVerse(verse: searchHistory.verse)
                                        dismissSearch()
                                    } label: {
                                        SearchResultVerseView(
                                            bibleReferenceText: "\(searchHistory.verse.bookName) \(searchHistory.verse.chapter):\(searchHistory.verse.verse)",
                                            verseText: searchHistory.verse.verseText ?? "",
                                            searchText: searchText
                                        )
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            viewModel.deleteSearchHistory(searchHistory)
                                            viewModel.loadSearchHistory()
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if let verse = viewModel.bibleReferenceVerse {
                            Section(header: Text("Bible Reference")) {
                                Button{
                                    viewModel.gotoVerse(verse: verse)
                                    viewModel.addSearchHistory(from: verse)
                                    dismissSearch()
                                } label: {
                                    SearchResultVerseView(
                                        bibleReferenceText: viewModel.bibleReferenceText ?? "",
                                        verseText: verse.verseText ?? "",
                                        searchText: searchText
                                    )
                                }
                            }
                        }
                        if !viewModel.groupedSearchResults.isEmpty {
                            Section(header: Text("Search Results")) {
                                ForEach(viewModel.groupedSearchResults.keys.sorted(by: { $0.bookOrder < $1.bookOrder }), id: \.self) { book in
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { expandedBooks.contains(book.bookName) },
                                            set: { isExpanded in
                                                if isExpanded {
                                                    expandedBooks.insert(book.bookName)
                                                } else {
                                                    expandedBooks.remove(book.bookName)
                                                }
                                            }
                                        )
                                    ) {
                                        ForEach(viewModel.groupedSearchResults[book] ?? [], id: \.self) { verse in
                                            Button{
                                                viewModel.gotoVerse(verse: verse)
                                                viewModel.addSearchHistory(from: verse)
                                                dismissSearch()
                                            } label: {
                                                SearchResultVerseView(
                                                    bibleReferenceText: "\(book.bookName) \(verse.chapter):\(verse.verse)",
                                                    verseText: verse.verseText ?? "",
                                                    searchText: searchText
                                                )
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(book.bookName)
                                            Text(viewModel.groupedSearchResults[book]?.count.description ?? "")
                                                .font(.caption)
                                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        EmptyView()
                    } footer: {
                        Color.clear.frame(height: 50)
                    }
                }
            }
            .onChange(of: searchText, initial: false) { _, searchText in
                viewModel.findBibleReference(text: searchText)
                viewModel.search(text: searchText)
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .navigationBarHidden(true)
            .safeAreaBar(edge: .bottom) {
                if searchText.isEmpty && !viewModel.searchHistories.isEmpty {
                    ActionBar {
                        ActionBarButton(action: { showClearSearchHistoryDialog = true }, systemImage: "trash")
                            .alert("검색 기록을 모두 삭제하시겠습니까?", isPresented: $showClearSearchHistoryDialog) {
                                Button("삭제", role: .destructive) {
                                    viewModel.clearSearchHistory()
                                    viewModel.loadSearchHistory()
                                }
                                Button("취소", role: .cancel) {}
                            } message: {
                                Text("이 작업은 되돌릴 수 없습니다.")
                            }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSearchHistory()
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return SearchView(searchText: .constant("be"))
}
