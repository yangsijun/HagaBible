//
//  BibleNavigationButton.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationButton<L: View, T: Equatable>: View {
    @Binding var selection: T?
    let label: (() -> L)
    let value: T
    let additionalAction: (() -> Void)?
    
    init(label: @escaping (() -> L), value: T, selection: Binding<T?>, additionalAction: (() -> Void)? = nil) {
        _selection = selection
        self.label = label
        self.value = value
        self.additionalAction = additionalAction
    }
    
    var body: some View {
        Button(action: {
            selection = value
            if let additionalAction = additionalAction {
                additionalAction()
            }
        }) {
            label()
                .frame(maxWidth: .infinity)
        }
        .background(
            value == selection.self ? Color.gray.opacity(0.2) : Color.clear
        )
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedBook: Book?
    let books = [
        Book(
            id: "book1",
            book: "1BK",
            bookOrder: 1,
            bookName: "1 Book",
            version: "MOCK",
            totalChapters: 2
        ),
        Book(
            id: "book2",
            book: "2BK",
            bookOrder: 2,
            bookName: "2 Book",
            version: "MOCK",
            totalChapters: 3
        )
    ]
    VStack {
        BibleNavigationButton(
            label: {
                Text(books[0].bookName)
            },
            value: books[0],
            selection: $selectedBook
        )
        BibleNavigationButton(
            label: {
                Text(books[1].bookName)
            },
            value: books[1],
            selection: $selectedBook
        )
    }
}
