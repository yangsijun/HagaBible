//
//  BibleNavigationColumnView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationColumnView<T: Hashable & Equatable, N: StringProtocol>: View {
    let columnTitle: String
    var itemList: [T]?
    @Binding var selectedItem: T?
    var getDesciption: (T) -> N
    var columnTitleAlignment: Alignment = .center
    var itemAlignment: Alignment = .center
    var additionalAction: (() -> Void)?
    var doubleTapAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            Text(columnTitle)
                .font(.headline)
                .padding(.vertical, 8)
                .padding(.horizontal, columnTitleAlignment == .center ? 8 : 0)
                .padding(.leading, columnTitleAlignment == .leading ? 16 : 0)
                .frame(maxWidth: .infinity, alignment: columnTitleAlignment)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if let items = itemList {
                            ForEach(0..<items.count, id: \.self) { index in
                                BibleNavigationButton(
                                    label: {
                                        Text(getDesciption(items[index]))
                                            .frame(maxWidth: .infinity, alignment: itemAlignment)
                                            .font(.pretendard(size: 20))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, itemAlignment == .center ? 8 : 0)
                                            .padding(.leading, itemAlignment == .leading ? 16 : 0)
                                            .background(
                                                Rectangle()
                                                    .frame(maxWidth: .infinity, alignment: itemAlignment)
                                                    .foregroundStyle(Color.clear)
                                            )
                                    },
                                    value: items[index],
                                    selection: $selectedItem,
                                    additionalAction: {
                                        if let action = additionalAction {
                                            action()
                                        }
                                    },
                                    doubleTapAction: {
                                        if let action = doubleTapAction {
                                            action()
                                        }
                                    }
                                )
                                .id(index)
                                Divider()
                            }
                        }
                    }
                }
                .onAppear {
                    if let selectedItem = selectedItem {
                        if let itemList = itemList {
                            let index = itemList.firstIndex(of: selectedItem) ?? 0
                            proxy.scrollTo(index, anchor: .top)
                            return
                        }
                    }
                    proxy.scrollTo(0, anchor: .top)
                }
                .onChange(of: itemList) {
                    if let selectedItem = selectedItem {
                        if let itemList = itemList {
                            let index = itemList.firstIndex(of: selectedItem) ?? 0
                            proxy.scrollTo(index, anchor: .top)
                            return
                        }
                    }
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedVerse: BibleVerse?
    let verses = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    
    NavigationStack {
        Text("")
        .sheet(isPresented: .constant(true)) {
            BibleNavigationColumnView(
                columnTitle: "절",
                itemList: verses,
                selectedItem: $selectedVerse,
                getDesciption: { "\($0.verse) 절" },
                additionalAction: {}
            )
        }
    }
}
