//
//  BibleVerseListView.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct BibleVerseListView: View {
    let verses: [BibleVerse]
    let language: String
    var fontConfiguration: FontConfiguration
    var theme: Theme
    var highlightedVerseNum: Int?
    var ttsCurrentVerseIndex: Int?

    var bibleActionService: BibleActionService = DIContainer.shared.resolve(type: BibleActionService.self)

    @Binding var selectStartIndex: Int?
    @Binding var selectEndIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(0)
            LazyVStack(spacing: CGFloat(fontConfiguration.lineSpacing)) {
                ForEach(0..<verses.count, id: \.self) { index in
                    BibleVerseView(
                        verseNumber: index + 1,
                        verseText: verses[index].verseText ?? "",
                        font: getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: CGFloat(fontConfiguration.size)),
                        textColor: theme.textColor,
                        verseNumberColor: theme.verseNumberColor,
                        alignment: fontConfiguration.alignment[language]?.nsAlignment ?? .natural,
                        lineSpacing: CGFloat(fontConfiguration.lineSpacing)
                    )
                    .id(index + 1)
                    .padding(8)
                    .padding(.horizontal, 8)
                    .background(
                        highlightedVerseNum == index + 1 ? Color.orange.opacity(0.25) : .clear
                    )
                    .background(
                        ttsCurrentVerseIndex == index ? Color.green.opacity(0.2) : .clear
                    )
                    .background(
                        (
                            selectStartIndex != nil
                            && selectEndIndex != nil
                            && index >= selectStartIndex!
                            && index <= selectEndIndex!
                        )
                        ? Color.accentColor.opacity(0.25)
                        : .clear
                    )
                    .contentShape(.rect)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = getVerseTextsFromContextMenuIndex(index)
                            selectStartIndex = nil
                            selectEndIndex = nil
                        }) {
                            Label("클립보드에 복사", systemImage: "doc.on.doc")
                        }
                        ShareLink(
                            item: getVerseTextsFromContextMenuIndex(index)
                        ) {
                            Label("공유하기", systemImage: "square.and.arrow.up")
                        }
                    } preview: {
                        if let start = selectStartIndex, let end = selectEndIndex, start <= index && index <= end {
                            NavigationStack {
                                VStack(spacing: 0) {
                                    ForEach(start...end, id: \.self) { idx in
                                        BibleVerseView(
                                            verseNumber: idx + 1,
                                            verseText: verses[idx].verseText ?? "",
                                            font: getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: CGFloat(fontConfiguration.size)),
                                            textColor: theme.textColor,
                                            verseNumberColor: theme.verseNumberColor,
                                            alignment: fontConfiguration.alignment[language]?.nsAlignment ?? .natural,
                                            lineSpacing: CGFloat(fontConfiguration.lineSpacing)
                                        )
                                        .padding(8)
                                        .padding(.horizontal, 8)
                                        .background(Color.accentColor.opacity(0.25))
                                    }
                                }
                            }
                        } else {
                            NavigationStack {
                                BibleVerseView(
                                    verseNumber: index + 1,
                                    verseText: verses[index].verseText ?? "",
                                    font: getUIFontFromFontConfiguration(fontConfiguration, language: language) ?? .systemFont(ofSize: CGFloat(fontConfiguration.size)),
                                    textColor: theme.textColor,
                                    verseNumberColor: theme.verseNumberColor,
                                    alignment: fontConfiguration.alignment[language]?.nsAlignment ?? .natural,
                                    lineSpacing: CGFloat(fontConfiguration.lineSpacing)
                                )
                                .padding(8)
                                .padding(.horizontal, 8)
                                .background(Color.accentColor.opacity(0.25))
                            }
                        }
                    }
                    .onTapGesture {
                        handleSelectVerse(index)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private func getVerseTextsFromContextMenuIndex(_ index: Int) -> String {
        let (start, end) = getSelectIndexFromContextMenuIndex(index)
        return bibleActionService.makeVerseStringFromVerseList(verses, start: start, end: end)
    }
    
    private func getSelectIndexFromContextMenuIndex(_ index: Int) -> (Int, Int) {
        if let selectStartIndex = selectStartIndex, let selectEndIndex = selectEndIndex {
            if index >= selectStartIndex && index <= selectEndIndex {
                return (selectStartIndex, selectEndIndex)
            }
        }
        return (index, index)
    }
    
    private func handleSelectVerse(_ index: Int) {
        guard selectStartIndex != nil, selectEndIndex != nil else {
            selectStartIndex = index
            selectEndIndex = index
            return
        }
        if index < selectStartIndex! {
            selectStartIndex = index
            return
        }
        if index == selectStartIndex! {
            if index == selectEndIndex! {
                selectStartIndex = nil
                selectEndIndex = nil
            } else {
                selectStartIndex! += 1
            }
            return
        }
        if index > selectStartIndex! {
            if index <= selectEndIndex! {
                selectEndIndex = index - 1
            } else {
                selectEndIndex = index
            }
        }
    }
}

#Preview {
    let verses: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
    ]
    
     BibleVerseListView(
        verses: verses,
        language: "Korean",
        fontConfiguration: FontConfiguration(
            type: [
                "English": .sans,
                "Korean": .serif,
            ],
            style: .regular,
            size: 17,
            alignment: [
                "English": .natural,
                "Korean": .justified
            ]
        ),
        theme: Theme.system,
        highlightedVerseNum: 1,
        ttsCurrentVerseIndex: nil,
        selectStartIndex: .constant(2),
        selectEndIndex: .constant(2)
    )
}
