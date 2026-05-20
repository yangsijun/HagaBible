//
//  BookmarkVerseHeader.swift
//  HagaBible
//
//  Created by 양시준 on 5/20/26.
//

import SwiftUI

/// Presentational header showing a verse reference and its text. Data is supplied
/// by the caller (loaded via `VerseTextLoader`), keeping this view free of I/O.
struct BookmarkVerseHeader: View {
    let reference: String
    let verseText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reference)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            if let verseText, !verseText.isEmpty {
                Text(verseText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    Form {
        Section {
            BookmarkVerseHeader(
                reference: "창세기 1:1-3",
                verseText: "태초에 하나님이 천지를 창조하시니라 …"
            )
        }
    }
}
