//
//  SearchView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismissSearch) var dismissSearch
    
    @Binding var searchText: String
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    @State private var expandedBooks: Set<String> = []
    
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
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
            .onChange(of: searchText) { _, searchText in
                viewModel.search(text: searchText)
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
        }
        .onAppear {
            viewModel.search(text: searchText)
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return SearchView(searchText: .constant("be"))
}
