//
//  DefaultTTSSettingsRepository.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation
import AVFoundation

/// UserDefaults 기반 TTS 설정 저장소 구현
class DefaultTTSSettingsRepository: TTSSettingsRepository {
    private enum Keys {
        static let koreanVoiceIdentifier = "tts_selected_korean_voice_identifier"
        static let englishVoiceIdentifier = "tts_selected_english_voice_identifier"
        static let speechRate = "tts_speech_rate"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSettings() -> TTSSettings {
        let savedRate = userDefaults.float(forKey: Keys.speechRate)
        let rate = savedRate > 0 ? savedRate : AVSpeechUtteranceDefaultSpeechRate

        return TTSSettings(
            speechRate: rate,
            koreanVoiceIdentifier: userDefaults.string(forKey: Keys.koreanVoiceIdentifier),
            englishVoiceIdentifier: userDefaults.string(forKey: Keys.englishVoiceIdentifier)
        )
    }

    func saveSettings(_ settings: TTSSettings) {
        userDefaults.set(settings.speechRate, forKey: Keys.speechRate)

        if let koreanId = settings.koreanVoiceIdentifier {
            userDefaults.set(koreanId, forKey: Keys.koreanVoiceIdentifier)
        } else {
            userDefaults.removeObject(forKey: Keys.koreanVoiceIdentifier)
        }

        if let englishId = settings.englishVoiceIdentifier {
            userDefaults.set(englishId, forKey: Keys.englishVoiceIdentifier)
        } else {
            userDefaults.removeObject(forKey: Keys.englishVoiceIdentifier)
        }
    }
}
