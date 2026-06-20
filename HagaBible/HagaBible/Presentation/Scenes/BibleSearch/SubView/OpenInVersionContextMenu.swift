//
//  OpenInVersionContextMenu.swift
//  HagaBible
//
//  Created by Codex on 6/20/26.
//

import SwiftUI

extension View {
    /// Attaches a context menu that opens the same passage in another downloaded
    /// version. Shared by search results and search history so both offer the
    /// identical "Open in Version" action.
    ///
    /// - Parameters:
    ///   - verse: The verse whose passage should be reopened elsewhere.
    ///   - viewModel: Source of the downloaded-version list and navigation.
    ///   - addToHistory: Whether selecting a version records a search-history
    ///     entry. Search results pass `true`; history items pass `false` to avoid
    ///     re-adding an entry the user is already tapping from.
    ///   - dismiss: Called after navigation (typically `dismissSearch`).
    @ViewBuilder
    func openInVersionContextMenu(
        for verse: BibleVerse,
        viewModel: SearchViewModel,
        addToHistory: Bool,
        dismiss: @escaping () -> Void
    ) -> some View {
        contextMenu {
            let others = viewModel.otherVersions(for: verse)
            if others.isEmpty {
                Label("No other versions", systemImage: "book.closed")
                    .disabled(true)
            } else {
                Section("Open in Version") {
                    ForEach(others, id: \.self) { version in
                        Button {
                            viewModel.gotoVerse(verse: verse, versionCode: version.versionCode)
                            if addToHistory {
                                viewModel.addSearchHistory(from: verse)
                            }
                            dismiss()
                        } label: {
                            Text(version.versionName)
                        }
                    }
                }
            }
        }
    }
}
