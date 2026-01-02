//
//  TTSPlaybackState.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// TTS 재생 상태
enum TTSPlaybackState: Equatable {
    /// 재생 중이 아님 (초기 상태)
    case idle
    /// 재생 중
    case playing
    /// 일시 정지
    case paused
}
