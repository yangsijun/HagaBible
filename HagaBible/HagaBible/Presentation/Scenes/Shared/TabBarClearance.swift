//
//  TabBarClearance.swift
//  HagaBible
//
//  Keeps floating controls clear of the tab bar, wherever the system puts it.
//

import SwiftUI
import UIKit

/// The tab bar is not part of the safe area in every layout: on a landscape iPhone its
/// pill and search circle float over the content, and on an unfolded foldable the bar
/// stands as a column on the trailing edge. Controls pinned to the bottom-trailing
/// corner measure the bar's visible pieces and step out of their way instead.
enum TabBarGeometry {
    /// Visible pieces of the window's tab bars, in window coordinates. A `UITabBar`'s
    /// own frame is a full-width strip (or the whole window on a foldable); only its
    /// shown subviews (the tab pill, the search circle, a trailing column) take space.
    static func visibleParts(in window: UIWindow) -> [CGRect] {
        var parts = tabBars(in: window)
            .filter { !$0.isHidden && $0.alpha > 0 }
            .flatMap { bar in
                bar.subviews
                    .filter { !$0.isHidden && $0.alpha > 0 && !$0.bounds.isEmpty }
                    .map { $0.convert($0.bounds, to: window) }
            }
        // System chrome that is not in the view hierarchy (a foldable's trailing tab
        // column may be) is reported as an occlusion region instead.
        if #available(iOS 27.1, *) {
            parts += window.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
        }
        return parts
    }

    static func tabBars(in view: UIView) -> [UITabBar] {
        var found: [UITabBar] = []
        if let bar = view as? UITabBar { found.append(bar) }
        for subview in view.subviews { found += tabBars(in: subview) }
        return found
    }

    /// How far something resting at `frame` must move up and left to keep `margin`
    /// clear of every part it touches. Each part is dodged the shorter way: a bottom
    /// pill is cleared by lifting, a trailing column by shifting left.
    static func clearance(for frame: CGRect, parts: [CGRect], margin: CGFloat = 8) -> (lift: CGFloat, shift: CGFloat) {
        var lift: CGFloat = 0
        var shift: CGFloat = 0
        for part in parts where part.insetBy(dx: -margin, dy: -margin).intersects(frame) {
            let up = frame.maxY + margin - part.minY
            let left = frame.maxX + margin - part.minX
            if up <= left { lift = max(lift, up) } else { shift = max(shift, left) }
        }
        return (lift, shift)
    }
}

/// Reports a view's window frame together with the tab bar's visible parts whenever
/// UIKit lays either out, so the owner can keep the view clear of the bar. Zero
/// footprint: use it as a `.background`.
struct TabBarClearanceReader: UIViewRepresentable {
    var onChange: (_ frame: CGRect, _ tabBarParts: [CGRect]) -> Void

    func makeUIView(context: Context) -> MarkerView {
        let view = MarkerView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: MarkerView, context: Context) {
        view.onChange = onChange
        // UIKit lays the marker out only when its own size changes; after a SwiftUI
        // update the bar may have moved (rotation, fold), so measure once more.
        view.lastReport = nil
        view.setNeedsLayout()
    }

    final class MarkerView: UIView {
        var onChange: ((CGRect, [CGRect]) -> Void)?
        var lastReport: (frame: CGRect, parts: [CGRect])?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
            // The tab bar can lay out after us in the same pass; look again afterwards.
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        private func report() {
            guard let window else { return }
            let frame = convert(bounds, to: window)
            let parts = TabBarGeometry.visibleParts(in: window)
            if let last = lastReport, last.frame == frame, last.parts == parts { return }
            lastReport = (frame, parts)
            onChange?(frame, parts)
        }
    }
}
