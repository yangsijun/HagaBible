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
    @Environment(\.isSearching) private var isSearching
    
    @Binding var searchText: String
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    
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
                            SearchHistoryView()
                        }
                    } else {
                        SearchResultsView(searchText: searchText)
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
            .safeAreaBar(edge: .bottom) {
                if !isSearching && searchText.isEmpty && !viewModel.searchHistories.isEmpty {
                    SearchHistoryActionBar()
                        .ignoresSafeArea(edges: .horizontal)
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadSearchHistory()
            viewModel.loadAvailableVersions()
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return SearchView(searchText: .constant("be"))
}
