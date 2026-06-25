//
//  BookmarksFilterBar.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

struct BookmarksFilterBar: View {
    @Bindable var viewModel: BookmarksViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                sortButton
                bookFilterMenu
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)
                colorFilter
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
    }

    private var sortButton: some View {
        Button {
            viewModel.toggleSort()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text(viewModel.sortOrder == .createdAtDesc ? "Recent" : "Biblical order")
                    .font(.caption)
            }
        }
        .buttonStyle(.glass)
        .foregroundStyle(Color(.label))
    }

    private var bookFilterMenu: some View {
        Menu {
            Button {
                viewModel.applyFilter(
                    color: viewModel.selectedColor,
                    bookCode: nil,
                    keyword: viewModel.keyword
                )
            } label: {
                if viewModel.selectedBookCode == nil {
                    Label("All books", systemImage: "checkmark")
                } else {
                    Text("All books")
                }
            }
            if !viewModel.availableBookCodes.isEmpty {
                Divider()
                ForEach(viewModel.availableBookCodes, id: \.self) { code in
                    Button {
                        viewModel.applyFilter(
                            color: viewModel.selectedColor,
                            bookCode: code,
                            keyword: viewModel.keyword
                        )
                    } label: {
                        if viewModel.selectedBookCode == code {
                            Label(viewModel.bookFilterDisplayName(for: code), systemImage: "checkmark")
                        } else {
                            Text(viewModel.bookFilterDisplayName(for: code))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "book")
                    .font(.caption)
                Text(viewModel.selectedBookCode.map { viewModel.bookFilterDisplayName(for: $0) } ?? "Book")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .buttonStyle(.glass)
        .foregroundStyle(viewModel.selectedBookCode == nil ? Color(.label) : Color(.accent))
    }

    private var colorFilter: some View {
        HStack(spacing: 10) {
            ForEach(BookmarkColor.allCases, id: \.self) { color in
                colorChip(color)
            }
        }
    }
    
    private func colorChip(_ color: BookmarkColor) -> some View {
        let isSelected = viewModel.selectedColor == color
        return BookmarkColorChip(color: color, isSelected: isSelected) {
            let newColor = isSelected ? nil : color
            viewModel.applyFilter(
                color: newColor,
                bookCode: viewModel.selectedBookCode,
                keyword: viewModel.keyword
            )
        }
    }
}

#Preview("Default") {
    BookmarksFilterBar(viewModel: BookmarksPreviewFactory.makeViewModel())
        .padding(.vertical)
}

#Preview("Color filter (yellow)") {
    BookmarksFilterBar(
        viewModel: BookmarksPreviewFactory.makeViewModel(selectedColor: .yellow)
    )
    .padding(.vertical)
}

#Preview("Book filter (GEN)") {
    BookmarksFilterBar(
        viewModel: BookmarksPreviewFactory.makeViewModel(selectedBookCode: "GEN")
    )
    .padding(.vertical)
}

#Preview("Biblical order sort") {
    BookmarksFilterBar(
        viewModel: BookmarksPreviewFactory.makeViewModel(sortOrder: .biblicalOrder)
    )
    .padding(.vertical)
}

#Preview("No available books") {
    BookmarksFilterBar(
        viewModel: BookmarksPreviewFactory.makeViewModel(seed: [])
    )
    .padding(.vertical)
}
