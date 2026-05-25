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
    /// Book orders whose chapter grid is expanded. Controlled (rather than letting
    /// each DisclosureGroup own its state) so arriving via the reader's "Reading
    /// Checklist" action can expand the target book programmatically.
    @State private var expandedBooks: Set<Int> = []

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
        ScrollViewReader { proxy in
            List {
                Section {
                    ReadingOverallProgress(read: viewModel.overallRead, total: viewModel.overallTotal)
                }
                ForEach(viewModel.books, id: \.bookOrder) { book in
                    Section {
                        DisclosureGroup(isExpanded: expansionBinding(for: book.bookOrder)) {
                            ReadingChapterGrid(book: book, viewModel: viewModel)
                        } label: {
                            ReadingBookRow(book: book, read: viewModel.readCount(forBook: book))
                        }
                    }
                    .id(book.bookOrder)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            // Freeze scrolling only while a chapter range is being drag-painted, so the
            // paint drag doesn't double as a scroll. Normal scrolling is unaffected.
            .scrollDisabled(viewModel.isDragPainting)
            // Jump to the book the reader was on when arriving via the reader's
            // "Reading Checklist" toolbar action. onAppear handles a fresh switch
            // into this section; onChange handles a target set while already shown.
            .onAppear { scrollToPendingTarget(proxy) }
            .onChange(of: viewModel.scrollTargetBookOrder) { _, _ in
                scrollToPendingTarget(proxy)
            }
        }
    }

    /// Scrolls to the pending target book (if any) and consumes it so it fires
    /// once. The brief delay lets the List realize its rows first — mirrors the
    /// reader's scroll-to-verse timing.
    private func scrollToPendingTarget(_ proxy: ScrollViewProxy) {
        guard let target = viewModel.scrollTargetBookOrder,
              viewModel.books.contains(where: { $0.bookOrder == target }) else { return }
        // Expand the target book so its chapter grid is visible on arrival. anchor:
        // .top pins the book row regardless of the grid's height (expansion adds
        // content below the row, not above), so expanding first won't shift the landing.
        expandedBooks.insert(target)
        // Consume after the scroll lands, not before: if the flow is interrupted in
        // the delay window the target survives for a retry, and in every real entry
        // path exactly one trigger fires, so this can't double-scroll.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(target, anchor: .top)
            viewModel.consumeScrollTarget()
        }
    }

    /// Two-way binding into `expandedBooks` for a single book's DisclosureGroup,
    /// so user taps and programmatic expansion share one source of truth.
    private func expansionBinding(for bookOrder: Int) -> Binding<Bool> {
        Binding(
            get: { expandedBooks.contains(bookOrder) },
            set: { isExpanded in
                if isExpanded {
                    expandedBooks.insert(bookOrder)
                } else {
                    expandedBooks.remove(bookOrder)
                }
            }
        )
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
