//
//  SearchHistoryActionBar.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import SwiftUI

struct SearchHistoryActionBar: View {
    @State private var viewModel: SearchViewModel = DIContainer.shared.resolve(type: SearchViewModel.self)
    @State private var showClearSearchHistoryDialog = false
    
    var body: some View {
        ActionBar {
            ActionBarButton(action: { showClearSearchHistoryDialog = true }, systemImage: "trash")
                .alert("Delete all search history?", isPresented: $showClearSearchHistoryDialog) {
                    Button("Delete", role: .destructive) {
                        viewModel.clearSearchHistory()
                        viewModel.loadSearchHistory()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
        }
    }
}
