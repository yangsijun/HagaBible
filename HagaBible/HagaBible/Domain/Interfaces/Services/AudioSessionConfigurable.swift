//
//  AudioSessionConfigurable.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

/// TTS 재생용 오디오 세션 설정 추상화
protocol AudioSessionConfigurable {
    func activatePlaybackSession() throws
    func deactivatePlaybackSession() throws
}
