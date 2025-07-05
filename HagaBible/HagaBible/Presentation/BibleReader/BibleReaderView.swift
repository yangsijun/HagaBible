//
//  BibleView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct BibleReaderView: View {
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)

    var body: some View {
        NavigationStack {
            Group {
                if let verses = viewModel.verses {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<verses.count, id: \.self) { index in
                                BibleVerseView(
                                    verseNumber: index + 1,
                                    verseText: verses[index].text
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    }
                } else {
                    Text("Loading...")
                }
            }
            .navigationTitle("\(viewModel.bookName ?? "") \(viewModel.chapterNum)")
        }
        .task {
            await viewModel.fetchAvailableVersions()
            await viewModel.fetchBibleContent(versionId: "WEBBE")
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return BibleReaderView()
}
