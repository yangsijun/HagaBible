//
//  ReadingChapterGrid.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI

/// Expanded chapter grid for one book. Tap a cell to toggle that chapter; long-press
/// then drag to fill a contiguous range (anchor…finger) with a single action. The
/// range/diff math lives in `ChapterRangePaint`; this view owns only the gesture and
/// the cell-frame hit-testing.
struct ReadingChapterGrid: View {
    let book: BibleBook
    let viewModel: ReadingChecklistViewModel

    private static let gridSpace = "readingChapterGrid"
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    /// Each chapter cell's frame in the grid's coordinate space — used to find
    /// which chapter the finger is over while drag-painting.
    @State private var chapterFrames: [Int: CGRect] = [:]
    /// Active drag-paint session (nil when not painting).
    @State private var paint: ChapterRangePaint?

    var body: some View {
        Group {
            if book.totalChapters >= 1 {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...book.totalChapters, id: \.self) { chapter in
                        chapterCell(chapter)
                    }
                }
                .padding(.vertical, 6)
                .coordinateSpace(.named(Self.gridSpace))
                .onPreferenceChange(ChapterFrameKey.self) { chapterFrames = $0 }
                .sensoryFeedback(.selection, trigger: paint?.range.count ?? 0)
                // A drag can be interrupted without onEnded (e.g. the row recycles);
                // finalize on disappear so a painted-but-unpersisted range isn't lost.
                .onDisappear { endDrag() }
            }
        }
    }

    private func chapterCell(_ chapter: Int) -> some View {
        let isRead = viewModel.isRead(bookCode: book.bookCode, chapter: chapter)
        return Text("\(chapter)")
            .font(.footnote)
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRead ? Color.accentColor : Color(.secondarySystemFill))
            )
            .foregroundStyle(isRead ? Color.white : Color.primary)
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ChapterFrameKey.self,
                        value: [chapter: geo.frame(in: .named(Self.gridSpace))]
                    )
                }
            )
            .onTapGesture {
                viewModel.toggleRead(book: book, chapter: chapter)
            }
            .gesture(paintGesture(anchor: chapter))
    }

    /// Long-press to begin, then drag to fill the contiguous range from the anchor
    /// to the finger (by chapter number, so row-wraps are covered). The 0.3s hold
    /// disambiguates from List scrolling — a quick pan still scrolls.
    private func paintGesture(anchor: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.gridSpace)))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if paint == nil {
                    // The anchor cell sets the action for the whole drag.
                    var session = ChapterRangePaint(
                        anchor: anchor,
                        target: !viewModel.isRead(bookCode: book.bookCode, chapter: anchor)
                    )
                    apply(session.update(to: anchor, isRead: isReadLookup))
                    paint = session
                }
                if let location = drag?.location, let chapter = chapter(at: location), var session = paint {
                    apply(session.update(to: chapter, isRead: isReadLookup))
                    paint = session
                }
            }
            .onEnded { _ in endDrag() }
    }

    private func apply(_ ops: [ChapterRangePaint.Op]) {
        for op in ops {
            viewModel.previewSetRead(bookCode: book.bookCode, chapter: op.chapter, isRead: op.isRead)
        }
    }

    private func endDrag() {
        guard let session = paint else { return }
        viewModel.persistDragSelection(book: book, chapters: session.changedChapters, isRead: session.target)
        paint = nil
    }

    private var isReadLookup: (Int) -> Bool {
        { viewModel.isRead(bookCode: book.bookCode, chapter: $0) }
    }

    private func chapter(at point: CGPoint) -> Int? {
        chapterFrames.first { $0.value.contains(point) }?.key
    }
}

/// Collects each chapter cell's frame so a drag can hit-test which cell it's over.
private struct ChapterFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
