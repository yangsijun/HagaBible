//
//  TTSPiPFrameRenderer.swift
//  HagaBible
//
//  Created by 양시준 on 8/19/26.
//

import AVFoundation
import UIKit

/// Renders the TTS chapter text into portrait 9:16 video frames for the Picture-in-
/// Picture window, mirroring the in-app reader's look: the user's theme colors, font
/// family/size/alignment/line-spacing settings, the verse-number column, and the same
/// green highlight the reader paints under the verse currently being spoken. The
/// layout keeps the verse just before the highlighted one at the top of the window
/// (or verse 1 itself when it is the first verse), so each verse advance looks like
/// the page auto-scrolled by one verse.
///
/// PiP can only display video, so the text is drawn into a bitmap once per verse
/// change and wrapped in a `CMSampleBuffer` for an `AVSampleBufferDisplayLayer`.
struct TTSPiPFrameRenderer {
    /// 9:16 portrait canvas. The PiP window shows it at roughly quarter size, so
    /// everything is drawn at `pipScale`× the reader's point metrics to stay legible.
    private static let canvasSize = CGSize(width: 720, height: 1280)
    /// Point→pixel boost over the in-app reader (~2× a 390pt-wide phone reader, so
    /// proportions match the reader while text reads slightly larger in the small window).
    private static let pipScale: CGFloat = 2

    /// Mirrors `BibleVerseListView.verseRowInnerPadding` (8pt) + its extra horizontal
    /// padding (8pt), scaled.
    private static let rowInnerPadding: CGFloat = 8 * pipScale
    private static let rowHorizontalExtraPadding: CGFloat = 8 * pipScale
    private static let headerBandHeight: CGFloat = 118
    /// Gap between the header band and the first drawn verse row (half the reader
    /// list's 16pt vertical padding — the header band provides enough separation).
    private static let contentTopPadding: CGFloat = 8 * pipScale

    let theme: Theme
    let fontConfiguration: FontConfiguration
    let language: String

    // MARK: - Public API

    /// - Parameters:
    ///   - startIndex: first verse row laid out at the top of the content area. The
    ///     canonical resting frame uses `max(currentIndex - 1, 0)`; scroll animations
    ///     pass the pre-transition anchor instead.
    ///   - topOffset: vertical shift (≤ 0 scrolls the content up) applied to the whole
    ///     verse stack, used to interpolate between two resting frames.
    func makeSampleBuffer(
        verses: [BibleVerse],
        currentIndex: Int,
        chapterTitle: String,
        startIndex: Int? = nil,
        topOffset: CGFloat = 0
    ) -> CMSampleBuffer? {
        let image = makeImage(
            verses: verses,
            currentIndex: currentIndex,
            chapterTitle: chapterTitle,
            startIndex: startIndex ?? max(currentIndex - 1, 0),
            topOffset: topOffset
        )
        guard let pixelBuffer = makePixelBuffer(from: image) else { return nil }
        return makeSampleBuffer(from: pixelBuffer)
    }

    /// Vertical distance (row heights + inter-row spacing) between the resting scroll
    /// positions anchored at `from` and `to` — the length a scroll animation travels.
    func scrollDistance(verses: [BibleVerse], from: Int, to: Int) -> CGFloat {
        let range = min(from, to)..<max(from, to)
        return range.reduce(CGFloat(0)) { total, index in
            total + verseRowHeight(verses[index]) + lineSpacing
        }
    }

    /// The light/dark style frames resolve the `.system` theme's dynamic colors
    /// against. PiP renders while the app is backgrounded, where the implicit
    /// `UITraitCollection.current` is unreliable, so the window scene's trait is
    /// read explicitly.
    static func currentInterfaceStyle() -> UIUserInterfaceStyle {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.traitCollection.userInterfaceStyle }
            .first ?? UITraitCollection.current.userInterfaceStyle
    }

    // MARK: - Reader-Matched Metrics

    private var traits: UITraitCollection {
        UITraitCollection(userInterfaceStyle: Self.currentInterfaceStyle())
    }

    private var bodyFont: UIFont {
        let base = getUIFontFromFontConfiguration(fontConfiguration, language: language)
            ?? .systemFont(ofSize: CGFloat(fontConfiguration.size))
        return base.withSize(base.pointSize * Self.pipScale)
    }

    /// Verse-number metrics, matching `BibleVerseView`'s proportional scaling around
    /// its 20pt base body size.
    private var verseNumberScale: CGFloat {
        CGFloat(fontConfiguration.size) / BibleVerseView.baseBodyFontSize
    }

    private var verseNumberFont: UIFont {
        .systemFont(ofSize: 12 * verseNumberScale * Self.pipScale)
    }

    private var verseNumberColumnWidth: CGFloat {
        BibleVerseView.verseNumberColumnWidth(forBodyFontSize: CGFloat(fontConfiguration.size)) * Self.pipScale
    }

    private var verseNumberSpacing: CGFloat {
        BibleVerseView.verseNumberSpacing * Self.pipScale
    }

    private var verseNumberMinHeight: CGFloat {
        22 * verseNumberScale * Self.pipScale
    }

    private var lineSpacing: CGFloat {
        CGFloat(fontConfiguration.lineSpacing) * Self.pipScale
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = fontConfiguration.alignment[language]?.nsAlignment ?? .natural
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return style
    }

    // MARK: - Drawing

    private func makeImage(
        verses: [BibleVerse],
        currentIndex: Int,
        chapterTitle: String,
        startIndex: Int,
        topOffset: CGFloat
    ) -> UIImage {
        let size = Self.canvasSize
        let traits = self.traits
        let backgroundColor = theme.backgroundColor.resolvedColor(with: traits)
        let textColor = theme.textColor.resolvedColor(with: traits)
        let verseNumberColor = theme.verseNumberColor.resolvedColor(with: traits)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            backgroundColor.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            // At rest the verse BEFORE the one being spoken anchors the top of the
            // window (verse 1 anchors itself); during a scroll animation `topOffset`
            // slides the whole stack so the next resting position eases in.
            var y = Self.headerBandHeight + Self.contentTopPadding + topOffset
            for index in startIndex..<verses.count {
                guard y < size.height else { break }
                y += drawVerseRow(
                    verses[index],
                    atY: y,
                    isCurrent: index == currentIndex,
                    textColor: textColor,
                    verseNumberColor: verseNumberColor
                ) + lineSpacing
            }

            // Opaque header band painted after the rows: mid-animation a row slides
            // underneath it and must disappear behind the header, not over it.
            backgroundColor.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: Self.headerBandHeight))

            let currentVerseNum = verses.indices.contains(currentIndex) ? verses[currentIndex].verse : 0
            let header = NSAttributedString(
                string: "\(chapterTitle)  ·  \(currentVerseNum)/\(verses.count)",
                attributes: [
                    .font: UIFont(name: Pretendard.medium.rawValue, size: 30) ?? .systemFont(ofSize: 30, weight: .medium),
                    .foregroundColor: verseNumberColor,
                ]
            )
            header.draw(in: CGRect(
                x: Self.rowInnerPadding + Self.rowHorizontalExtraPadding,
                y: 48,
                width: size.width - (Self.rowInnerPadding + Self.rowHorizontalExtraPadding) * 2,
                height: 40
            ))
        }
    }

    /// Draws one verse row laid out like `BibleVerseView` (number column + text) and
    /// returns its height. The current verse gets the reader's full-width green
    /// highlight instead of any PiP-specific accent.
    private func drawVerseRow(
        _ verse: BibleVerse,
        atY y: CGFloat,
        isCurrent: Bool,
        textColor: UIColor,
        verseNumberColor: UIColor
    ) -> CGFloat {
        let rowHeight = verseRowHeight(verse)

        if isCurrent {
            // Same marker the reader uses for the spoken verse (BibleVerseListView).
            UIColor.systemGreen.withAlphaComponent(0.2).setFill()
            UIRectFillUsingBlendMode(
                CGRect(x: 0, y: y, width: Self.canvasSize.width, height: rowHeight),
                .normal
            )
        }

        let contentX = Self.rowInnerPadding + Self.rowHorizontalExtraPadding
        let contentY = y + Self.rowInnerPadding
        let numberWidth = numberColumnWidth(for: verse.verse)

        // Verse number, centered in its column like BibleVerseView's min-sized frame.
        let number = NSAttributedString(string: "\(verse.verse)", attributes: [
            .font: verseNumberFont,
            .foregroundColor: verseNumberColor,
        ])
        let numberSize = number.size()
        number.draw(at: CGPoint(
            x: contentX + (numberWidth - numberSize.width) / 2,
            y: contentY + max(0, (verseNumberMinHeight - numberSize.height) / 2)
        ))

        let text = attributedText(for: verse, textColor: textColor)
        let textX = contentX + numberWidth + verseNumberSpacing
        text.draw(
            with: CGRect(
                x: textX,
                y: contentY,
                width: textWidth(for: verse.verse),
                height: rowHeight - Self.rowInnerPadding * 2
            ),
            options: [.usesLineFragmentOrigin],
            context: nil
        )

        return rowHeight
    }

    private func verseRowHeight(_ verse: BibleVerse) -> CGFloat {
        let bounds = attributedText(for: verse, textColor: .black).boundingRect(
            with: CGSize(width: textWidth(for: verse.verse), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        return max(ceil(bounds.height), verseNumberMinHeight) + Self.rowInnerPadding * 2
    }

    private func attributedText(for verse: BibleVerse, textColor: UIColor) -> NSAttributedString {
        NSAttributedString(string: verse.verseText ?? "", attributes: [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ])
    }

    private func numberColumnWidth(for verseNumber: Int) -> CGFloat {
        let digitsWidth = ceil(("\(verseNumber)" as NSString)
            .size(withAttributes: [.font: verseNumberFont]).width)
        return max(verseNumberColumnWidth, digitsWidth)
    }

    private func textWidth(for verseNumber: Int) -> CGFloat {
        Self.canvasSize.width
            - (Self.rowInnerPadding + Self.rowHorizontalExtraPadding) * 2
            - numberColumnWidth(for: verseNumber)
            - verseNumberSpacing
    }

    // MARK: - Video Frame Conversion

    private func makePixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let size = Self.canvasSize
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            // IOSurface backing is required for AVSampleBufferDisplayLayer rendering.
            kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any](),
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer, let cgImage = image.cgImage else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        // A still frame: no duration, presented immediately at "now".
        let timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        guard let formatDescription = try? CMVideoFormatDescription(imageBuffer: pixelBuffer),
              let sampleBuffer = try? CMSampleBuffer(
                  imageBuffer: pixelBuffer,
                  formatDescription: formatDescription,
                  sampleTiming: timing
              ) else {
            return nil
        }
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachmentsArray) > 0 {
            let attachments = unsafeBitCast(CFArrayGetValueAtIndex(attachmentsArray, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                attachments,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sampleBuffer
    }
}
