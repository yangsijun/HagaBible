//
//  SearchView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.search(text: searchText).prefix(100), id: \.self) { verse in
                    SearchResultVerseView(
                        bibleReferenceText: viewModel.getBibleReferenceString(verse: verse),
                        verseText: verse.verseText ?? "",
                        searchText: searchText
                    )
                }
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
