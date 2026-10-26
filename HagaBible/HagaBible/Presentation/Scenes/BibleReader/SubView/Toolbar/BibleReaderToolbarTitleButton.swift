//
//  BibleReaderToolbarTitleButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI
import UIKit

struct BibleReaderToolbarTitleButton: View {
    let bibleBook: BibleBook?
    let chapterNum: Int
    let bibleVersion: BibleVersion?

    /// Reader content width (≈ the window width), measured by the parent. The title computes
    /// how much it must scale down to fit this (minus a fixed chrome allowance) and applies
    /// that as the `minimumScaleFactor` floor, so it keeps its natural `.title2` size whenever
    /// there's room and shrinks only as much as a genuinely narrow window requires — never
    /// dropped, never truncated.
    let availableWidth: CGFloat

    /// Window x the title's glass pill should start at, when the reader wants it lined up
    /// with its verse column (paged mode, where a side safe area pushes the text inward).
    /// The bar's own pill can't be moved (padding only grows it, a spacer item costs a
    /// whole item slot), so in that case the item's shared background is hidden, the
    /// button draws its own glass, and leading padding outside the glass does the moving.
    let alignedLeadingX: CGFloat?
    /// Leading padding currently applied; corrected from the measured pill position.
    @State private var leadingShift: CGFloat = 0
    /// Corrections left for the current target: a safety net so a bar that never
    /// settles can't keep the layout spinning.
    @State private var correctionsLeft = 0
    private static let correctionBudget = 6

    /// Re-evaluate the (Dynamic-Type-derived) base sizes when the user changes text size.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var showBibleNavigation: Bool

    var chapterCounterNoun: String {
        getChapterCounterNoun(bookCode: bibleBook?.bookCode ?? "", versionLanguage: bibleVersion?.language ?? "")
    }

    private var bookChapterString: String {
        "\(bibleBook?.bookName ?? "") \(chapterNum)\(chapterCounterNoun)"
    }

    private var versionString: String {
        bibleVersion?.versionShortName ?? ""
    }

    /// Natural sizes: `.title2` for the book/chapter, `.caption` for the version — read
    /// from the current Dynamic Type so the title still respects the user's text-size setting.
    private var baseTitleSize: CGFloat { UIFont.preferredFont(forTextStyle: .title2).pointSize }
    private var baseVersionSize: CGFloat { UIFont.preferredFont(forTextStyle: .caption1).pointSize }

    /// Spacing between the book/chapter and the version, matched in both the layout and
    /// the width measurement so the computed scale is accurate.
    private var titleSpacing: CGFloat { 6 }

    /// Fixed top-bar width the title can't use: the trailing ••• menu, bar margins, and —
    /// on iPad in multitasking (Stage Manager / Split View) — the leading window-control
    /// "grab" pill, which sits in the bar's leading area and pushes the title inward (the
    /// big, easy-to-miss cost). Kept generous so the title's *minimum* width stays inside the
    /// real slot and the leading item is never dropped; in a non-multitasking window (no
    /// pill) this only over-shrinks the title slightly, which is harmless. (SwiftUI doesn't
    /// expose the navigation bar's internal insets, so this is a fixed allowance.)
    private var horizontalReserve: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 200 : 110
    }

    /// How much the title may shrink to fit the measured available width: `1` when it
    /// already fits at full size (so it never shrinks when there's room), otherwise the exact
    /// ratio down to a 0.4 floor. This value is used as the `minimumScaleFactor` floor in
    /// `adaptiveTitle`: measuring the width with `UIFont` lets the floor be exactly `1` in a
    /// wide window, which is what prevents the "tiny in a wide window" that a *fixed*
    /// `minimumScaleFactor` causes on a leading bar item (the bar hands a compressible
    /// leading item its minimum width even when the bar is wide).
    private var scale: CGFloat {
        guard availableWidth > 0 else { return 1 }
        let titleFont = UIFont.systemFont(ofSize: baseTitleSize, weight: .bold)
        let versionFont = UIFont.systemFont(ofSize: baseVersionSize)
        let titleWidth = (bookChapterString as NSString).size(withAttributes: [.font: titleFont]).width
        let versionWidth = versionString.isEmpty
            ? 0
            : titleSpacing + (versionString as NSString).size(withAttributes: [.font: versionFont]).width
        let ideal = titleWidth + versionWidth
        let available = max(1, availableWidth - horizontalReserve)
        guard ideal > available else { return 1 }
        return max(0.4, available / ideal)
    }

    var body: some View {
        if alignedLeadingX != nil, #available(iOS 26.0, *) {
            button
                .buttonStyle(.glass)
                // Without the shared background the bar offers the item its minimum
                // width, which collapses the compressible title; claim the natural size.
                .fixedSize()
                // A UIKit marker under the pill (inside the padding) reports the pill's
                // final window x the moment the bar lays it out: UIKit lays out once per
                // change, unlike SwiftUI geometry, which also reports every animated
                // frame on the way and would feed the shift back into itself.
                .background(WindowPositionMarker { x in adjustShift(measuredX: x) })
                .padding(.leading, leadingShift)
                .onAppear { correctionsLeft = Self.correctionBudget }
                .onChange(of: alignedLeadingX) { correctionsLeft = Self.correctionBudget }
                .onChange(of: availableWidth) { correctionsLeft = Self.correctionBudget }
        } else {
            button
        }
    }

    /// One correction step per layout, within the budget; padding moves the pill
    /// one-to-one, so the first step lands it and later layouts find nothing to do.
    private func adjustShift(measuredX: CGFloat) {
        guard let alignedLeadingX, correctionsLeft > 0 else { return }
        let delta = alignedLeadingX - measuredX
        guard abs(delta) >= 0.5 else { return }
        correctionsLeft -= 1
        leadingShift = max(0, leadingShift + delta)
    }

    @ViewBuilder
    private var button: some View {
        if #available(iOS 26.0, *) {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                adaptiveTitle
                    .foregroundStyle(Color(.label))
                    // The glass button style pads more than the bar's pill; 2pt brings
                    // its height back to the bar's 44pt.
                    .padding(.vertical, alignedLeadingX == nil ? 8 : 2)
            }
        } else {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                adaptiveTitle
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
            }
            .toolbarButtonStyle(.capsule)
        }
    }

    /// The book/chapter and version at their natural sizes. `minimumScaleFactor(scale)` makes
    /// the title *compressible* so the navigation bar shrinks it to fit a cramped top bar
    /// (e.g. a narrow iPad multitasking window, where the leading window-control pill steals
    /// room) instead of dropping the whole leading item. The floor is the measured `scale`,
    /// which is `1` whenever the title already fits, so a wide window keeps it at full size —
    /// no "tiny in a wide window". Both Texts share the factor, so they shrink uniformly.
    private var adaptiveTitle: some View {
        HStack(spacing: titleSpacing) {
            Text(bookChapterString)
                .font(.system(size: baseTitleSize, weight: .bold))
            Text(versionString)
                .font(.system(size: baseVersionSize))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(scale)
    }
}


/// Invisible view that reports its own window x after each UIKit layout pass.
private struct WindowPositionMarker: UIViewRepresentable {
    let onLayout: (CGFloat) -> Void

    func makeUIView(context: Context) -> MarkerView {
        let view = MarkerView()
        view.isUserInteractionEnabled = false
        view.onLayout = onLayout
        return view
    }

    func updateUIView(_ view: MarkerView, context: Context) {
        view.onLayout = onLayout
        // The marker's own bounds never change, so UIKit won't lay it out again when the
        // bar moves it (rotation, fold), and a new target with an unmoved pill would be
        // deduplicated away. Every SwiftUI update of the title asks for one fresh report
        // on the next layout pass, when the bar's frames are final.
        view.lastX = nil
        view.setNeedsLayout()
    }

    final class MarkerView: UIView {
        var onLayout: ((CGFloat) -> Void)?
        var lastX: CGFloat?

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            guard window != nil else { return }
            let x = convert(bounds, to: nil).minX
            guard x != lastX else { return }
            lastX = x
            onLayout?(x)
        }
    }
}

#Preview {
    ZStack {
        BibleReaderToolbarTitleButton(
            bibleBook: .init(bookCode: "GEN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
            chapterNum: 1,
            bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
            availableWidth: 0,
            alignedLeadingX: nil,
            showBibleNavigation: .constant(false)
        )
    }
}
