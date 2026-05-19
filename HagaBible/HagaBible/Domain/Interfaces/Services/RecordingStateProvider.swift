//
//  RecordingStateProvider.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

/// 현재 녹음 상태 조회 추상화
protocol RecordingStateProvider {
    var isRecording: Bool { get }
}
