//
//  SystemAudioSessionConfigurator.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import AVFoundation
import Foundation

final class SystemAudioSessionConfigurator: AudioSessionConfigurable {
    func activatePlaybackSession() throws {
#if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try audioSession.setActive(true)
#endif
    }

    func deactivatePlaybackSession() throws {
#if os(iOS)
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }
}
