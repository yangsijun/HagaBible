//
//  ReadingChapterGrid.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import SwiftUI
import UIKit

/// Expanded chapter grid for one book. Tap a cell to toggle that chapter; long-press
/// then drag to fill a contiguous range (anchor…finger) with a single action. The
/// range/diff math lives in `ChapterRangePaint`; this view owns only the gesture and
/// the cell-frame hit-testing.
///
/// Scroll coexistence (the hard part): on iOS 18+, SwiftUI's own `DragGesture` /
/// `LongPressGesture` — even via `.simultaneousGesture` — hijack the touch from an
/// enclosing `List`, so the list only scrolls in the gaps between cells. The fix is to
/// bridge a real UIKit `UILongPressGestureRecognizer` through `UIGestureRecognizerRepresentable`
/// (WWDC24) and let it recognize *simultaneously* with the list's scroll pan, so a quick
/// pan scrolls (the long press fails on movement) while a deliberate hold starts painting.
/// While painting we suspend the list's scroll via `viewModel.isDragPainting` so the
/// paint drag doesn't also scroll.
struct ReadingChapterGrid: View {
    let book: BibleBook
    let viewModel: ReadingChecklistViewModel

    private static let gridSpace = "readingChapterGrid"
    private static let holdToPaint: TimeInterval = 0.3

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
                .gesture(
                    ChapterPaintGesture(
                        coordinateSpace: Self.gridSpace,
                        minimumPressDuration: Self.holdToPaint,
                        onBegan: beginPaint(at:),
                        onChanged: extendPaint(to:),
                        onEnded: endDrag
                    )
                )
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
            // Tap toggles a single chapter; a plain tap never blocks list scrolling.
            .onTapGesture {
                viewModel.toggleRead(book: book, chapter: chapter)
            }
    }

    // MARK: - Paint handlers (driven by the bridged long-press recognizer)

    /// The long press fired: the cell under the finger anchors the range and sets the
    /// action (read↔unread) for the whole drag. Suspend list scrolling while painting.
    private func beginPaint(at location: CGPoint) {
        guard let anchor = chapter(at: location) else { return }
        viewModel.isDragPainting = true
        var session = ChapterRangePaint(
            anchor: anchor,
            target: !viewModel.isRead(bookCode: book.bookCode, chapter: anchor)
        )
        apply(session.update(to: anchor, isRead: isReadLookup))
        paint = session
    }

    /// Extend the painted range to the chapter currently under the finger.
    private func extendPaint(to location: CGPoint) {
        guard let chapter = chapter(at: location), var session = paint else { return }
        apply(session.update(to: chapter, isRead: isReadLookup))
        paint = session
    }

    private func apply(_ ops: [ChapterRangePaint.Op]) {
        for op in ops {
            viewModel.previewSetRead(bookCode: book.bookCode, chapter: op.chapter, isRead: op.isRead)
        }
    }

    private func endDrag() {
        if let session = paint {
            viewModel.persistDragSelection(book: book, chapters: session.changedChapters, isRead: session.target)
        }
        paint = nil
        viewModel.isDragPainting = false
    }

    private var isReadLookup: (Int) -> Bool {
        { viewModel.isRead(bookCode: book.bookCode, chapter: $0) }
    }

    private func chapter(at point: CGPoint) -> Int? {
        chapterFrames.first { $0.value.contains(point) }?.key
    }
}

/// Bridges a UIKit `UILongPressGestureRecognizer` into SwiftUI. Unlike SwiftUI's native
/// gestures, this coexists with an enclosing `List`/`ScrollView`: its coordinator opts
/// into simultaneous recognition, so the scroll pan keeps working and the long press only
/// wins once the finger has been held in place past `minimumPressDuration`.
private struct ChapterPaintGesture: UIGestureRecognizerRepresentable {
    /// Named coordinate space the reported locations are resolved into (matches the grid).
    let coordinateSpace: String
    let minimumPressDuration: TimeInterval
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.location(in: .named(coordinateSpace))
        switch recognizer.state {
        case .began:
            onBegan(location)
        case .changed:
            onChanged(location)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// Collects each chapter cell's frame so a drag can hit-test which cell it's over.
private struct ChapterFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
