//
//  TTSSettings.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation
import AVFoundation

/// TTS 사용자 설정
struct TTSSettings: Equatable, Codable {
    /// 음성 속도 (AVSpeechUtteranceDefaultSpeechRate 기준)
    var speechRate: Float

    /// 선택된 한국어 음성 식별자 (nil = 시스템 기본값)
    var koreanVoiceIdentifier: String?

    /// 선택된 영어 음성 식별자 (nil = 시스템 기본값)
    var englishVoiceIdentifier: String?

    /// 기본 설정값
    static let `default` = TTSSettings(
        speechRate: AVSpeechUtteranceDefaultSpeechRate,
        koreanVoiceIdentifier: nil,
        englishVoiceIdentifier: nil
    )
}
