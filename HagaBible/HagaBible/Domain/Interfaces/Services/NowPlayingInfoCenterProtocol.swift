//
//  NowPlayingInfoCenterProtocol.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation
import MediaPlayer

/// 시스템 Now Playing 정보 센터 추상화 프로토콜
@MainActor
protocol NowPlayingInfoCenterProtocol: AnyObject {
    /// 현재 Now Playing 메타데이터 업데이트
    func updateNowPlayingInfo(_ info: [String: Any])

    /// 현재 재생 상태 업데이트
    func setPlaybackState(_ state: MPNowPlayingPlaybackState)

    /// 현재 Now Playing 정보 제거
    func clearNowPlayingInfo()
}
