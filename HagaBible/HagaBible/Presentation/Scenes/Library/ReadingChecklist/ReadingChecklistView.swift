//
//  ReadingChecklistView.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// The 성경읽기표 section of the Library tab: a per-chapter read/unread checklist.
/// Composed of small subviews — see the `SubView` folder for the chapter grid,
/// progress rows, and the reset toolbar.
struct ReadingChecklistView: View {
    let viewModel: ReadingChecklistViewModel

    @State private var showResetConfirmation = false

    var body: some View {
        Group {
            if viewModel.books.isEmpty {
                ReadingChecklistEmptyState()
            } else {
                bookList
            }
        }
        .toolbar {
            ReadingChecklistToolbarContent(
                viewModel: viewModel,
                showResetConfirmation: $showResetConfirmation
            )
        }
        .task {
            // Load once; segment switches must not re-fetch (the data persists
            // in the view model and marks change only in place here).
            if viewModel.books.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var bookList: some View {
        List {
            Section {
                ReadingOverallProgress(read: viewModel.overallRead, total: viewModel.overallTotal)
            }
            ForEach(viewModel.books, id: \.bookOrder) { book in
                Section {
                    DisclosureGroup {
                        ReadingChapterGrid(book: book, viewModel: viewModel)
                    } label: {
                        ReadingBookRow(book: book, read: viewModel.readCount(forBook: book))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
    }
}

#Preview("With progress") {
    NavigationStack {
        ReadingChecklistView(viewModel: ReadingChecklistPreviewFactory.makeViewModel())
            .navigationTitle("Reading")
    }
}

#Preview("Empty") {
    ReadingChecklistView(viewModel: ReadingChecklistPreviewFactory.makeViewModel(books: []))
}
