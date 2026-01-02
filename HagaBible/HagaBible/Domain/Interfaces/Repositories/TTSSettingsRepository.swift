//
//  TTSSettingsRepository.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// TTS 설정 저장소 프로토콜
protocol TTSSettingsRepository {
    /// 저장된 설정 불러오기
    func loadSettings() -> TTSSettings

    /// 설정 저장하기
    func saveSettings(_ settings: TTSSettings)
}
