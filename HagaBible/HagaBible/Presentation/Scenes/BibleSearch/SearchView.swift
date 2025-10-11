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
    @State private var bibleReferences: [BibleVerse: String] = [:]
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    var body: some View {
        NavigationStack {
            List {
//            ScrollView {
//                LazyVStack {
                    ForEach(viewModel.searchResults, id: \.self) { verse in
                        Button{
                            viewModel.gotoVerse(verse: verse)
                            dismissSearch()
                        } label: {
                            SearchResultVerseView(
                                bibleReferenceText: bibleReferences[verse] ?? "",
                                verseText: verse.verseText ?? "",
                                searchText: searchText
                            )
                            .task {
                                let ref = await viewModel.getBibleReferenceString(verse: verse)
                                bibleReferences[verse] = ref
                            }
                        }
                    }
                }
                .onChange(of: searchText) { _, searchText in
                    viewModel.search(text: searchText)
//                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return SearchView(searchText: .constant("be"))
}
