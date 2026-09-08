//
//  TTSFollowScroll.swift
//  HagaBible
//
//  Created by 양시준 on 9/8/26.
//

import SwiftUI

/// Where the reader parks the verse being read aloud while TTS auto-follows.
///
/// `ScrollViewProxy.scrollTo(_:anchor:)` aligns the *same* unit point of the target row
/// and of the visible area, so a fixed anchor equal to `line` keeps the row's *own*
/// `line` point on the line — and the row's top edge then drifts upward by that
/// fraction of the row height, i.e. long verses sit visibly higher than short ones.
/// `anchor(rowHeight:visibleHeight:)` solves for the unit point that puts the row's
/// **top edge** on the line instead, so every verse starts at the same height
/// regardless of how many lines it spans.
nonisolated enum TTSFollowScroll {
    /// Fraction of the visible reading area (below the toolbar, above the action bar)
    /// at which the spoken verse's top edge rests: a verse or two of context above,
    /// the upcoming verses filling the rest, lyrics-style.
    static let line: CGFloat = 0.2

    /// Anchor for `scrollTo` that places the row's top edge at `line`.
    ///
    /// With anchor `y`, SwiftUI puts the row's top at `y·H − y·h = y·(H − h)`; setting
    /// that equal to `line·H` gives `y = line·H / (H − h)`.
    ///
    /// - Parameters:
    ///   - rowHeight: measured height of the verse row, or `nil` when it has not been
    ///     laid out yet (e.g. a jump to a row the lazy stack has not materialized). Falls
    ///     back to the plain fraction, which is at worst a few tens of points off.
    ///   - visibleHeight: height of the scroll view's visible area
    ///     (`ScrollGeometry.containerSize.height`), the same rect the anchor is
    ///     measured against.
    static func anchor(rowHeight: CGFloat?, visibleHeight: CGFloat) -> UnitPoint {
        guard let rowHeight, rowHeight > 0, visibleHeight > 0 else {
            return UnitPoint(x: 0.5, y: line)
        }
        let remaining = visibleHeight - rowHeight
        // A row as tall as the area or taller can only be shown from its top.
        guard remaining > 0 else { return UnitPoint(x: 0.5, y: 0) }
        // y > 1 would mean the row's bottom passes the area's bottom; the closest the
        // same-point alignment can get is bottom-aligned (top ends up above the line).
        return UnitPoint(x: 0.5, y: min(line * visibleHeight / remaining, 1))
    }
}
