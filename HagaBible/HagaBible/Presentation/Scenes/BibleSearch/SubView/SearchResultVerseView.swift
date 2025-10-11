//
//  SearchResultVerseView.swift
//  HagaBible
//
//  Created by 양시준 on 10/8/25.
//

import SwiftUI

struct SearchResultVerseView: View {
    var bibleReferenceText: String
    var verseText: String
    var searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bibleReferenceText)
                .font(.caption)
                .foregroundStyle(Color.accent)
            AdvancedText(
                attributedText: NSMutableAttributedString(
                    string: verseText,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 17),
                        .foregroundColor: UIColor.label
                    ]
                )
                .addingAttributes([.backgroundColor: UIColor.accent.withAlphaComponent(0.5)], toSubstring: searchText)
                .addingAttributes([.foregroundColor: UIColor.label], toSubstring: searchText)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SearchResultVerseView(
        bibleReferenceText: "Genesis 1:1",
        verseText: "In the beginning, God created the heavens and the earth.",
        searchText: "beginning"
    )
}
