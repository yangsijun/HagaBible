//
//  VoiceProvider.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// 음성 목록 제공자 프로토콜
protocol VoiceProvider {
    /// 특정 언어에 대해 사용 가능한 음성 목록 반환
    /// - Parameter language: "Korean" 또는 "English"
    /// - Returns: 품질순으로 정렬된 음성 목록
    func availableVoices(for language: String) -> [TTSVoiceConfig]

    /// 식별자로 음성 찾기
    /// - Parameter identifier: 음성 식별자
    /// - Returns: 해당 음성 설정 (없으면 nil)
    func voice(for identifier: String) -> TTSVoiceConfig?

    /// 시스템 기본 음성 가져오기
    /// - Parameter language: "Korean" 또는 "English"
    /// - Returns: 해당 언어의 시스템 기본 음성 (없으면 nil)
    func defaultVoice(for language: String) -> TTSVoiceConfig?
}
