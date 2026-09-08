//
//  SystemAudioSessionConfigurator.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import AVFoundation
import Foundation

final class SystemAudioSessionConfigurator: AudioSessionConfigurable {
    func activatePlaybackSession() async throws {
#if os(iOS)
        // Off the main thread: setCategory/setActive block on the audio server.
        try await AudioSessionQueue.run {
            let audioSession = AVAudioSession.sharedInstance()
            // No `.duckOthers`: ducking marks the audio as transient/secondary (like a
            // navigation prompt), which disqualifies the app from becoming the system
            // "Now Playing" app — so the Lock Screen / Control Center card never appears
            // even though nowPlayingInfo is set. Bible reading is primary long-form
            // spoken audio (podcast-like), so it should take over playback instead.
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
        }
#endif
    }

    func deactivatePlaybackSession() async throws {
#if os(iOS)
        try await AudioSessionQueue.run {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
#endif
    }
}
