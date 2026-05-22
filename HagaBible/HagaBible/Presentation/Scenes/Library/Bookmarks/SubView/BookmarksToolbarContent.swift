//
//  BookmarksToolbarContent.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct BookmarksToolbarContent: ToolbarContent {
    let viewModel: BookmarksViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.toggleIndicator()
            } label: {
                if viewModel.isBookmarkIndicatorEnabled {
                    Label("Hide bookmark stripes", systemImage: "inset.filled.leadingthird.rectangle")
                } else {
                    Label("Show bookmark stripes", systemImage: "rectangle")
                }
            }
        }
    }
}

private struct BookmarksToolbarPreviewHost: View {
    let viewModel: BookmarksViewModel

    var body: some View {
        NavigationStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .navigationTitle("Bookmarks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    BookmarksToolbarContent(viewModel: viewModel)
                }
        }
    }
}

#Preview("Indicator ON") {
    BookmarksToolbarPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel(indicatorEnabled: true)
    )
}

#Preview("Indicator OFF") {
    BookmarksToolbarPreviewHost(
        viewModel: BookmarksPreviewFactory.makeViewModel(indicatorEnabled: false)
    )
}
