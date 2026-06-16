//
//  RecordingPlaybackState.swift
//  HagaBible
//
//  Created by 양시준 on 6/16/26.
//

import Foundation

/// 녹음 파일 재생 상태 (TTSPlaybackState를 미러링)
enum RecordingPlaybackState: Equatable {
    /// 재생 중이 아님 (초기 상태)
    case idle
    /// 재생 중
    case playing
    /// 일시 정지
    case paused
}
