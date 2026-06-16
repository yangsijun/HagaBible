//
//  RecordingPlaybackManager.swift
//  HagaBible
//
//  Created by 양시준 on 6/16/26.
//

import AVFoundation
import Foundation
import OSLog

/// Plays back a single saved recording file via `AVAudioPlayer`.
///
/// Mirrors `TTSPlaybackManager`'s role for recordings: the single source of truth for
/// playback state, driving a time-based scrubber. Unlike TTS — which must render
/// synthesized speech through an audio engine to register as the system "Now Playing"
/// app — a real recorded file plays directly through `AVAudioPlayer`.
///
/// **Shared audio session.** Recording playback and TTS share the process-wide
/// `AVAudioSession`. `play(_:)` pauses any active TTS so the two never play over each
/// other. The reverse collision — starting TTS while a recording plays — is unreachable:
/// the player is a modal sheet over the tab bar, and dismissing it stops playback. The
/// session is intentionally left active on `stop()` (unlike TTS, which deactivates):
/// `AudioService` activates the `.playAndRecord` session once at launch and never
/// re-activates it before recording, so deactivating here would silence the next
/// recording.
///
/// **Now Playing deferred.** Lock Screen / remote-command / Now Playing integration is
/// intentionally NOT wired here. `MPRemoteCommandCenter` is a shared singleton and
/// `TTSPlaybackManager` already owns its handlers for the whole app lifetime, so a second
/// set registered here would double-fire on both managers. Coexistence needs a
/// command-router refactor; until then recording playback is in-app/foreground only.
@MainActor
@Observable
final class RecordingPlaybackManager: NSObject {
    // MARK: - Public State

    private(set) var playbackState: RecordingPlaybackState = .idle
    /// Identifies which recording is currently loaded (used by the re-tap/resume path).
    private(set) var currentRecordingID: UUID?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // MARK: - Dependencies

    private let ttsManager: TTSPlaybackManager
    private let interruptionObservable: InterruptionObservable

    // MARK: - Private

    private var player: AVAudioPlayer?
    /// Polls `AVAudioPlayer.currentTime` while playing to advance the scrubber.
    private var tickTask: Task<Void, Never>?
    private var interruptionObserverToken: NSObjectProtocol?

    // MARK: - Initialization

    init(
        ttsManager: TTSPlaybackManager,
        interruptionObservable: InterruptionObservable
    ) {
        self.ttsManager = ttsManager
        self.interruptionObservable = interruptionObservable
        super.init()
        setupInterruptionHandling()
    }

    // MARK: - Playback Control

    /// Starts playback of `recording`. Re-tapping the recording that is already loaded
    /// resumes from its paused position instead of restarting from the beginning.
    func play(_ recording: Recording) {
        if currentRecordingID == recording.id, player != nil {
            resume()
            return
        }

        let url = FileManager.documentsDirectory.appendingPathComponent(recording.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.audio.error("Recording file not found for playback: \(url.lastPathComponent)")
            return
        }

        // Silence TTS before taking over the shared session. Pause (not stop): stop()
        // deactivates the session on a later runloop, which would kill the playback we
        // start below. Only when TTS is actually playing — pausing an idle TTS would
        // flip it to .paused and wrongly surface the TTS mini-player.
        if ttsManager.playbackState == .playing {
            ttsManager.pause()
        }

        activatePlaybackSession()

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()

            player = newPlayer
            currentRecordingID = recording.id
            duration = newPlayer.duration
            currentTime = 0

            newPlayer.play()
            playbackState = .playing
            startTick()
            Logger.audio.info("Playing recording: \(recording.title)")
        } catch {
            Logger.audio.error("Failed to start playback: \(error.localizedDescription)")
            player = nil
            playbackState = .idle
        }
    }

    func togglePlayPause() {
        switch playbackState {
        case .playing: pause()
        case .paused: resume()
        case .idle: break
        }
    }

    func pause() {
        guard let player, playbackState == .playing else { return }
        player.pause()
        currentTime = player.currentTime
        playbackState = .paused
        stopTick()
    }

    func resume() {
        guard let player, playbackState == .paused else { return }
        activatePlaybackSession()
        player.play()
        playbackState = .playing
        startTick()
    }

    func stop() {
        player?.stop()
        player = nil
        playbackState = .idle
        currentRecordingID = nil
        currentTime = 0
        duration = 0
        stopTick()
    }

    /// Moves playback to `time` (seconds), clamped to the file bounds.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = Self.clampedTime(time, duration: duration)
        player.currentTime = target
        currentTime = target
    }

    func skipForward(_ seconds: TimeInterval = 15) {
        seek(to: Self.skipTarget(current: currentTime, delta: seconds, duration: duration))
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        seek(to: Self.skipTarget(current: currentTime, delta: -seconds, duration: duration))
    }

    // MARK: - Pure Helpers (unit-tested)

    /// Formats a duration as `m:ss`. Minutes are not zero-padded and may exceed 59,
    /// matching `AudioService.getRecordingTimeText`. Non-finite/negative values render
    /// as `0:00`.
    nonisolated static func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Clamps `time` to `0...duration` (and to 0 when the duration is unknown/zero).
    nonisolated static func clampedTime(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return min(max(time, 0), duration)
    }

    /// Seek target after applying `delta` (positive or negative) to `current`, clamped
    /// to the file bounds.
    nonisolated static func skipTarget(current: TimeInterval, delta: TimeInterval, duration: TimeInterval) -> TimeInterval {
        clampedTime(current + delta, duration: duration)
    }

    // MARK: - Private Helpers

    private func startTick() {
        stopTick()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.playbackState == .playing, let player = self.player else { return }
                self.currentTime = player.currentTime
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func activatePlaybackSession() {
        // AVAudioSession is iOS-only. Keep the category record-capable (.playAndRecord)
        // so playing a recording never disables a subsequent recording, and default to
        // the speaker so playback is audible instead of routing to the earpiece.
        guard !PlatformHelper.isRunningOnMac else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            Logger.audio.error("Failed to activate playback session: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Interruption Handling

    private func setupInterruptionHandling() {
        guard !PlatformHelper.isRunningOnMac else { return }
        interruptionObserverToken = interruptionObservable.addInterruptionObserver { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // iOS has already paused the player; sync our state so the scrubber stops
            // and the UI shows the play button.
            if playbackState == .playing {
                pause()
                Logger.audio.info("Recording playback paused due to audio interruption")
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && playbackState == .paused {
                    resume()
                    Logger.audio.info("Recording playback resumed after audio interruption")
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RecordingPlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Reset to the start and pause — NOT stop. The player and currentRecordingID
            // are deliberately kept so a play tap replays instantly from 0:00. Full
            // teardown (releasing the player) happens when the sheet is dismissed
            // (RecordingPlayerView.onDisappear → stop()).
            self.player?.currentTime = 0
            self.currentTime = 0
            self.playbackState = .paused
            self.stopTick()
            Logger.audio.info("Recording playback finished (success: \(flag))")
        }
    }
}
