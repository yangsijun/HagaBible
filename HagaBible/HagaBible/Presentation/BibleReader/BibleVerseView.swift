//
//  BibleVerseView.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import SwiftUI

struct BibleVerseView: View {
    var verseNumber: Int
    var verseText: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(verseNumber)")
                .frame(width: 24, height: 22, alignment: .center)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verseText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
