//
//  SearchHistoryView.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import SwiftUI

struct SearchHistoryView: View {
    @Environment(\.dismissSearch) var dismissSearch
    
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    @State private var showClearSearchHistoryDialog = false
    
    var body: some View {
        Section(header: Text("Search History")) {
            ForEach(viewModel.searchHistories) { searchHistory in
                Button{
                    viewModel.gotoVerse(verse: searchHistory.verse)
                    dismissSearch()
                } label: {
                    SearchResultVerseView(
                        bibleReferenceText: "\(searchHistory.verse.bookName) \(searchHistory.verse.chapter):\(searchHistory.verse.verse)",
                        verseText: searchHistory.verse.verseText ?? ""
                    )
                }
                .openInVersionContextMenu(for: searchHistory.verse, viewModel: viewModel, addToHistory: false, dismiss: { dismissSearch() })
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteSearchHistory(searchHistory)
                        viewModel.loadSearchHistory()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}
