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
        if #available(iOS 26.0, *) {
            Button(action: {
                showBibleNavigation.toggle()
            }) {
                adaptiveTitle
                    .foregroundStyle(Color(.label))
                    .padding(.vertical, 8)
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

#Preview {
    ZStack {
        BibleReaderToolbarTitleButton(
            bibleBook: .init(bookCode: "GEN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
            chapterNum: 1,
            bibleVersion: .init(versionCode: "KRV", versionName: "개역한글", versionShortName: "개역한글", language: "Korean", isDownloaded: true),
            availableWidth: 0,
            showBibleNavigation: .constant(false)
        )
    }
}
