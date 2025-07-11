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
        .foregroundStyle(.primary)
        .background(
            value == selection.self ? Color.gray.opacity(0.2) : Color.clear
        )
    }
}

#Preview {
    @Previewable @State var selectedBibleBook: BibleBook?
    let bibleBooks = [
        BibleBook(
            bookCode: "1BK", bookName: "1 Book", bookOrder: 1, totalChapters: 2, versionCode: "MOCK"
        ),
        BibleBook(
            bookCode: "2BK", bookName: "2 Book", bookOrder: 2, totalChapters: 3, versionCode: "MOCK"
        )
    ]
    VStack {
        BibleNavigationButton(
            label: {
                Text(bibleBooks[0].bookName)
            },
            value: bibleBooks[0],
            selection: $selectedBibleBook
        )
        BibleNavigationButton(
            label: {
                Text(bibleBooks[1].bookName)
            },
            value: bibleBooks[1],
            selection: $selectedBibleBook
        )
    }
}
