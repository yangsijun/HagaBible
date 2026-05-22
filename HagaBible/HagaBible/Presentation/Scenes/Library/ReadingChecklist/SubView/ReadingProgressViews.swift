//
//  ReadingProgressViews.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// Overall reading progress shown at the top of the checklist.
struct ReadingOverallProgress: View {
    let read: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Overall")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(read) / \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(read), total: Double(max(total, 1)))
                .tint(.accentColor)
        }
        .padding(.vertical, 2)
    }
}

/// A book's row label: name, a completion check when fully read, and a read/total count.
struct ReadingBookRow: View {
    let book: BibleBook
    let read: Int

    private var isComplete: Bool { book.totalChapters > 0 && read == book.totalChapters }

    var body: some View {
        HStack(spacing: 10) {
            Text(book.bookName)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
            Text("\(read)/\(book.totalChapters)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// Shown when no bible version is downloaded, so there is no book list to check off.
struct ReadingChecklistEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No bible downloaded")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
