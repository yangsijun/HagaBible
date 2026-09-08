//
//  AudioSessionConfigurable.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

/// TTS 재생용 오디오 세션 설정 추상화.
///
/// Both calls are `async` because the real implementation must not block the main
/// thread on the audio server (see `AudioSessionQueue`); callers sequence playback
/// after the activation has actually completed.
protocol AudioSessionConfigurable {
    func activatePlaybackSession() async throws
    func deactivatePlaybackSession() async throws
}
