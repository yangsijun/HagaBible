//
//  SearchResultsView.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import SwiftUI

struct SearchResultsView: View {
    @Environment(\.dismissSearch) var dismissSearch
    
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    var searchText: String
    @State private var expandedBooks: Set<String> = []
    
    var body: some View {
        if let verse = viewModel.bibleReferenceVerse {
            Section(header: Text("Bible Reference")) {
                Button{
                    viewModel.gotoVerse(verse: verse)
                    viewModel.addSearchHistory(from: verse)
                    dismissSearch()
                } label: {
                    SearchResultVerseView(
                        bibleReferenceText: viewModel.bibleReferenceText ?? "",
                        verseText: verse.verseText ?? ""
                    )
                }
                .openInVersionContextMenu(for: verse, viewModel: viewModel, addToHistory: true, dismiss: { dismissSearch() })
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
                                    highlightedText: searchText
                                )
                            }
                            .openInVersionContextMenu(for: verse, viewModel: viewModel, addToHistory: true, dismiss: { dismissSearch() })
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

}
