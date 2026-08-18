//
//  TTSPictureInPictureService.swift
//  HagaBible
//
//  Created by 양시준 on 8/19/26.
//

import AVKit
import OSLog
import UIKit

/// Drives the system Picture-in-Picture window that mirrors a TTS reading session:
/// when the user leaves the app while listening, a portrait 9:16 PiP window shows the
/// chapter text auto-followed to the verse currently being spoken, and its play/pause
/// button is wired both ways to the TTS engine.
///
/// PiP can only present video, so each verse change is rendered into a bitmap frame
/// (see `TTSPiPFrameRenderer`) and enqueued on an `AVSampleBufferDisplayLayer` that
/// backs the `AVPictureInPictureController` content source. AVKit requires that layer
/// to live in the app's view hierarchy for PiP to become "possible", so RootView embeds
/// a near-invisible 1pt host view while a session is active (`TTSPiPLayerHostView`);
/// this service owns everything behind that layer.
@MainActor
final class TTSPictureInPictureService: NSObject {
    private let ttsManager: TTSPlaybackManager
    private let fontThemeManager: FontThemeManager

    private weak var displayLayer: AVSampleBufferDisplayLayer?
    private var pipController: AVPictureInPictureController?

    /// Identity of the last frame pushed to the layer. Playback-state toggles also fire
    /// the observation below, so frames are deduped to actual position/content changes.
    /// Theme, font settings, and the resolved light/dark style are part of the identity
    /// so appearance changes mid-session produce a fresh frame.
    private struct FrameKey: Equatable {
        let bookCode: String
        let chapter: Int
        let verseIndex: Int
        let verseCount: Int
        let theme: Theme
        let fontConfiguration: FontConfiguration
        let interfaceStyle: UIUserInterfaceStyle
    }

    private var lastFrameKey: FrameKey?
    /// In-flight verse-to-verse scroll animation; cancelled whenever a newer frame
    /// (next verse, forced redraw, detach) supersedes it.
    private var animationTask: Task<Void, Never>?

    init(ttsManager: TTSPlaybackManager, fontThemeManager: FontThemeManager) {
        self.ttsManager = ttsManager
        self.fontThemeManager = fontThemeManager
        super.init()
        observePlayback()
    }

    // MARK: - Layer Attachment (called by TTSPiPLayerHostView)

    func attach(layer: AVSampleBufferDisplayLayer) {
        guard !PlatformHelper.isRunningOnMac,
              AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard displayLayer !== layer else { return }

        displayLayer = layer
        lastFrameKey = nil

        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: layer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        // Start PiP by itself when the user leaves for the Home Screen mid-playback.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller

        enqueueCurrentFrame()
        Logger.tts.debug("PiP: controller attached to display layer")
    }

    func detach() {
        guard pipController != nil || displayLayer != nil else { return }
        animationTask?.cancel()
        animationTask = nil
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController = nil
        displayLayer = nil
        lastFrameKey = nil
        Logger.tts.debug("PiP: controller detached")
    }

    // MARK: - TTS Observation

    /// Re-arming `withObservationTracking` loop over the playback manager's state.
    /// The service is an app-lifetime singleton, so the loop runs for the app's life;
    /// it early-outs while no display layer is attached.
    private func observePlayback() {
        withObservationTracking {
            _ = ttsManager.isSessionActive
            _ = ttsManager.playbackState
            _ = ttsManager.currentVerseIndex
            _ = ttsManager.verses
            // Re-render when the user changes theme/font settings mid-session.
            _ = fontThemeManager.theme
            _ = fontThemeManager.fontConfiguration
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handlePlaybackChange()
                self.observePlayback()
            }
        }
    }

    private func handlePlaybackChange() {
        guard let pipController else { return }

        guard ttsManager.isSessionActive else {
            // Session ended (stop button, chapter run-out). RootView will also drop the
            // host view, but close the floating window immediately rather than leaving
            // a frozen frame until SwiftUI catches up.
            if pipController.isPictureInPictureActive {
                pipController.stopPictureInPicture()
            }
            return
        }

        // Keep the PiP play/pause button in sync with pauses triggered elsewhere
        // (mini player, lock screen, interruptions).
        pipController.invalidatePlaybackState()
        enqueueCurrentFrame()
    }

    // MARK: - Frame Rendering

    private func enqueueCurrentFrame(force: Bool = false) {
        guard displayLayer != nil else { return }
        let verses = ttsManager.verses
        guard !verses.isEmpty else { return }

        let index = min(ttsManager.currentVerseIndex, verses.count - 1)
        let key = FrameKey(
            bookCode: ttsManager.bookCode,
            chapter: ttsManager.chapterNum,
            verseIndex: index,
            verseCount: verses.count,
            theme: fontThemeManager.theme,
            fontConfiguration: fontThemeManager.fontConfiguration,
            interfaceStyle: TTSPiPFrameRenderer.currentInterfaceStyle()
        )
        guard force || key != lastFrameKey else { return }

        let previousKey = lastFrameKey
        lastFrameKey = key
        animationTask?.cancel()
        animationTask = nil

        let renderer = TTSPiPFrameRenderer(
            theme: fontThemeManager.theme,
            fontConfiguration: fontThemeManager.fontConfiguration,
            language: ttsManager.currentLanguage
        )

        if !force, let previousKey, shouldAnimateScroll(from: previousKey, to: key) {
            let oldAnchor = max(previousKey.verseIndex - 1, 0)
            let newAnchor = max(index - 1, 0)
            if oldAnchor != newAnchor {
                startScrollAnimation(
                    renderer: renderer,
                    verses: verses,
                    currentIndex: index,
                    chapterTitle: ttsManager.chapterTitle,
                    from: oldAnchor,
                    to: newAnchor
                )
                return
            }
        }

        enqueue(renderer.makeSampleBuffer(
            verses: verses,
            currentIndex: index,
            chapterTitle: ttsManager.chapterTitle
        ))
    }

    private func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        guard let displayLayer else { return }
        guard let sampleBuffer else {
            Logger.tts.error("PiP: failed to render verse frame")
            return
        }
        let videoRenderer = displayLayer.sampleBufferRenderer
        if videoRenderer.requiresFlushToResumeDecoding {
            videoRenderer.flush()
        }
        videoRenderer.enqueue(sampleBuffer)
    }

    // MARK: - Scroll Animation

    /// Animate only ordinary verse advances within the same chapter and appearance:
    /// a chapter/theme/font change is a content swap, not a scroll, and animating a
    /// big skip would fly past many verses. Skipped when the PiP window is closed —
    /// nobody sees the layer, so the extra frames are pure waste.
    private func shouldAnimateScroll(from old: FrameKey, to new: FrameKey) -> Bool {
        pipController?.isPictureInPictureActive == true
            && old.bookCode == new.bookCode
            && old.chapter == new.chapter
            && old.verseCount == new.verseCount
            && old.theme == new.theme
            && old.fontConfiguration == new.fontConfiguration
            && old.interfaceStyle == new.interfaceStyle
            && abs(new.verseIndex - old.verseIndex) <= 3
    }

    /// Slides the verse stack from the `from` anchor's resting position to the `to`
    /// anchor's over ~0.4s by enqueueing eased intermediate frames (~33fps). Runs as a
    /// cancellable task so a rapid next verse/skip starts a fresh animation instead of
    /// fighting a stale one.
    private func startScrollAnimation(
        renderer: TTSPiPFrameRenderer,
        verses: [BibleVerse],
        currentIndex: Int,
        chapterTitle: String,
        from oldAnchor: Int,
        to newAnchor: Int
    ) {
        let startIndex = min(oldAnchor, newAnchor)
        let distance = renderer.scrollDistance(verses: verses, from: oldAnchor, to: newAnchor)
        let forward = newAnchor > oldAnchor
        let frameCount = 14
        let frameDuration = 0.42 / Double(frameCount)

        animationTask = Task { @MainActor [weak self] in
            for step in 1...frameCount {
                guard let self, !Task.isCancelled else { return }
                let progress = Double(step) / Double(frameCount)
                let eased = CGFloat(1 - pow(1 - progress, 3)) // ease-out cubic
                let travelled = forward ? eased * distance : (1 - eased) * distance
                self.enqueue(renderer.makeSampleBuffer(
                    verses: verses,
                    currentIndex: currentIndex,
                    chapterTitle: chapterTitle,
                    startIndex: startIndex,
                    topOffset: -travelled
                ))
                try? await Task.sleep(for: .seconds(frameDuration))
            }
            // Land exactly on the canonical resting frame.
            guard let self, !Task.isCancelled else { return }
            self.enqueue(renderer.makeSampleBuffer(
                verses: verses,
                currentIndex: currentIndex,
                chapterTitle: chapterTitle
            ))
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

// @preconcurrency: AVKit invokes these on the main thread, but the protocol is not
// MainActor-annotated; the runtime check this adds is satisfied in practice.
extension TTSPictureInPictureService: @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        if playing {
            ttsManager.resume()
        } else {
            ttsManager.pause()
        }
        pictureInPictureController.invalidatePlaybackState()
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // "Live" range: hides the scrubber/skip UI, leaving the play/pause control.
        CMTimeRange(start: .negativeInfinity, end: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        ttsManager.playbackState != .playing
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // The layer may have been flushed for the size change; push a fresh frame.
        enqueueCurrentFrame(force: true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        // Not reachable with the live time range above, but map sensibly anyway.
        if skipInterval.seconds < 0 {
            ttsManager.skipToPrevious()
        } else {
            ttsManager.skipToNext()
        }
        completionHandler()
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension TTSPictureInPictureService: @preconcurrency AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Guarantee the window opens on the current verse even if dedupe skipped the
        // last enqueue (e.g. layer was re-created between sessions).
        enqueueCurrentFrame(force: true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Logger.tts.error("PiP: failed to start — \(error.localizedDescription)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Nothing to restore: the reader UI is always behind the PiP window.
        completionHandler(true)
    }
}
