//
//  SystemNowPlayingInfoCenter.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation
import MediaPlayer

/// MPNowPlayingInfoCenter 시스템 구현체
@MainActor
final class SystemNowPlayingInfoCenter: NowPlayingInfoCenterProtocol {
    func updateNowPlayingInfo(_ info: [String: Any]) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setPlaybackState(_ state: MPNowPlayingPlaybackState) {
        MPNowPlayingInfoCenter.default().playbackState = state
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
