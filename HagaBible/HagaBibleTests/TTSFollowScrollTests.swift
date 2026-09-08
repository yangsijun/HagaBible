import Testing
import SwiftUI
@testable import HagaBible

@Suite("TTS follow-scroll anchor")
struct TTSFollowScrollTests {
    /// Top edge SwiftUI produces for a `scrollTo` anchor `y`: `y·H − y·h`.
    private func rowTop(anchorY: CGFloat, rowHeight h: CGFloat, visibleHeight H: CGFloat) -> CGFloat {
        anchorY * H - anchorY * h
    }

    @Test("Row top lands on the line regardless of row height", arguments: [44.0, 88.0, 140.0, 300.0] as [CGFloat])
    func rowTopIsOnTheLine(rowHeight: CGFloat) {
        let visible: CGFloat = 596
        let anchor = TTSFollowScroll.anchor(rowHeight: rowHeight, visibleHeight: visible)
        let top = rowTop(anchorY: anchor.y, rowHeight: rowHeight, visibleHeight: visible)
        #expect(abs(top - TTSFollowScroll.line * visible) < 0.001)
        #expect(anchor.x == 0.5)
    }

    @Test("A fixed 0.3 anchor drifts with row height (the bug this replaces)")
    func fixedAnchorDrifts() {
        let visible: CGFloat = 596
        let shortTop = rowTop(anchorY: 0.3, rowHeight: 44, visibleHeight: visible)
        let tallTop = rowTop(anchorY: 0.3, rowHeight: 140, visibleHeight: visible)
        #expect(shortTop - tallTop > 25)
    }

    @Test("Unknown row height falls back to the plain fraction")
    func unknownHeightFallsBack() {
        #expect(TTSFollowScroll.anchor(rowHeight: nil, visibleHeight: 596).y == TTSFollowScroll.line)
        #expect(TTSFollowScroll.anchor(rowHeight: 0, visibleHeight: 596).y == TTSFollowScroll.line)
        #expect(TTSFollowScroll.anchor(rowHeight: 44, visibleHeight: 0).y == TTSFollowScroll.line)
    }

    @Test("Row too tall to sit on the line is bottom-clamped, never past 1")
    func tallRowClampsToBottom() {
        // 0.3·H / (H − h) > 1 once h > 0.7·H.
        let anchor = TTSFollowScroll.anchor(rowHeight: 500, visibleHeight: 596)
        #expect(anchor.y == 1)
    }

    @Test("Row taller than the area is shown from its top")
    func oversizedRowAnchorsTop() {
        #expect(TTSFollowScroll.anchor(rowHeight: 596, visibleHeight: 596).y == 0)
        #expect(TTSFollowScroll.anchor(rowHeight: 900, visibleHeight: 596).y == 0)
    }
}
