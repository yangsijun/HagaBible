//
//  ChapterRangePaint.swift
//  HagaBible
//
//  Created by 양시준 on 5/22/26.
//

/// Pure range-selection state for the long-press-drag chapter painter. Holds only
/// chapter-number math — no SwiftUI, gestures, or coordinates — so it's unit-testable
/// and portable (the Android port mirrors this logic). The owning view feeds it the
/// finger's current chapter and applies the returned ops to its live preview.
struct ChapterRangePaint: Equatable {
    /// The long-pressed chapter the range is anchored to.
    let anchor: Int
    /// The action applied across the whole drag: true = mark read, false = unmark.
    /// Decided once from the anchor's pre-drag state so a mixed-state range paints
    /// uniformly.
    let target: Bool

    /// Contiguous chapter range currently selected (anchor…finger).
    private(set) var range: Set<Int> = []
    /// Pre-drag read-state of every chapter the range has ever covered, so cells
    /// dropped when the range shrinks can revert and release persists only changes.
    private(set) var originalStates: [Int: Bool] = [:]

    init(anchor: Int, target: Bool) {
        self.anchor = anchor
        self.target = target
    }

    /// A single preview mutation: set `chapter` to `isRead`.
    struct Op: Equatable {
        let chapter: Int
        let isRead: Bool
    }

    /// Moves the selection to anchor…current and returns the preview ops to apply:
    /// chapters entering the range take `target`; chapters leaving revert to their
    /// captured pre-drag state. `isRead` supplies the pre-drag state the first time
    /// a chapter is seen.
    mutating func update(to current: Int, isRead: (Int) -> Bool) -> [Op] {
        let lower = min(anchor, current)
        let upper = max(anchor, current)
        let desired = Set(lower...upper)

        var ops: [Op] = []
        for chapter in desired.subtracting(range).sorted() {
            if originalStates[chapter] == nil {
                originalStates[chapter] = isRead(chapter)
            }
            ops.append(Op(chapter: chapter, isRead: target))
        }
        for chapter in range.subtracting(desired).sorted() {
            ops.append(Op(chapter: chapter, isRead: originalStates[chapter] ?? false))
        }
        range = desired
        return ops
    }

    /// Chapters whose final state differs from their pre-drag original — the only
    /// ones that need persisting on release.
    var changedChapters: [Int] {
        range.filter { originalStates[$0] != target }.sorted()
    }
}
