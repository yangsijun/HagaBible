//
//  BibleNavigationColumnView.swift
//  HagaBible
//
//  Created by 양시준 on 7/8/25.
//

import SwiftUI

struct BibleNavigationColumnView<T: Identifiable & Equatable, N: StringProtocol>: View {
    let columnTitle: String
    var itemList: [T]?
    @Binding var selectedItem: T?
    var getDesciption: (T) -> N
    var columnTitleAlignment: Alignment = .center
    var itemAlignment: Alignment = .center
    var additionalAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            Text(columnTitle)
                .font(.headline)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: columnTitleAlignment)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if let items = itemList {
                        ForEach(items) { item in
                            BibleNavigationButton(
                                label: {
                                    Text(getDesciption(item))
                                        .frame(maxWidth: .infinity, alignment: itemAlignment)
                                        .font(.pretendard(size: 20))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                        .background(
                                            Rectangle()
                                                .frame(maxWidth: .infinity, alignment: itemAlignment)
                                                .foregroundStyle(Color.clear)
                                        )
                                },
                                value: item,
                                selection: $selectedItem,
                                additionalAction: {
                                    if let action = additionalAction {
                                        action()
                                    }
                                }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedVerse: Verse?
    let verses = [
        Verse(id: "GN1_1_WEBBE", canonOrder: "002_001_001", book: "GEN", chapter: 1, verse: 1, version: "WEBBE", text: "In the beginning, God created the heavens and the earth."),
        Verse(id: "GN1_2_WEBBE", canonOrder: "002_001_002", book: "GEN", chapter: 1, verse: 2, version: "WEBBE", text: "The earth was formless and empty. Darkness was on the surface of the deep and God’s Spirit was hovering over the surface of the waters."),
        Verse(id: "GN1_3_WEBBE", canonOrder: "002_001_003", book: "GEN", chapter: 1, verse: 3, version: "WEBBE", text: "God said, “Let there be light,” and there was light.")
    ]
    
    NavigationStack {
        Text("")
        .sheet(isPresented: .constant(true)) {
            BibleNavigationColumnView(
                columnTitle: "절",
                itemList: verses,
                selectedItem: $selectedVerse,
                getDesciption: { "\($0.verse) 절" },
                additionalAction: {
                    print("additional action")
                }
            )
        }
    }
}
