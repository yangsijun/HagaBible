//
//  AVVoiceProvider.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation
import AVFoundation

/// AVSpeechSynthesisVoice 기반 음성 제공자 구현
class AVVoiceProvider: VoiceProvider {
    private var cachedKoreanVoices: [TTSVoiceConfig]?
    private var cachedEnglishVoices: [TTSVoiceConfig]?
    private var allVoicesMap: [String: TTSVoiceConfig] = [:]

    init() {
        loadVoices()
    }

    func availableVoices(for language: String) -> [TTSVoiceConfig] {
        if language == "Korean" {
            return cachedKoreanVoices ?? []
        } else {
            return cachedEnglishVoices ?? []
        }
    }

    func voice(for identifier: String) -> TTSVoiceConfig? {
        allVoicesMap[identifier]
    }

    func defaultVoice(for language: String) -> TTSVoiceConfig? {
        let languageCode: String
        if language == "Korean" {
            languageCode = "ko-KR"
        } else {
            // 사용자의 preferred languages에서 영어 locale 찾기
            languageCode = Locale.preferredLanguages.first { $0.hasPrefix("en") } ?? "en-US"
        }

        guard let systemDefault = AVSpeechSynthesisVoice(language: languageCode) else {
            return nil
        }
        return mapToConfig(systemDefault)
    }

    // MARK: - Private Methods

    private func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Korean: ko-KR only
        let koreanVoices = allVoices
            .filter { $0.language == "ko-KR" }
            .map { mapToConfig($0) }
        cachedKoreanVoices = filterVoicesByQuality(koreanVoices)

        // English: en-US and en-GB
        let englishVoices = allVoices
            .filter { $0.language == "en-US" || $0.language == "en-GB" }
            .map { mapToConfig($0) }
        cachedEnglishVoices = filterVoicesByQuality(englishVoices)

        // Build lookup map
        for voice in (cachedKoreanVoices ?? []) + (cachedEnglishVoices ?? []) {
            allVoicesMap[voice.identifier] = voice
        }
    }

    private func mapToConfig(_ voice: AVSpeechSynthesisVoice) -> TTSVoiceConfig {
        TTSVoiceConfig(
            identifier: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: mapQuality(voice.quality)
        )
    }

    private func mapQuality(_ quality: AVSpeechSynthesisVoiceQuality) -> TTSVoiceConfig.VoiceQuality {
        switch quality {
        case .premium:
            return .premium
        case .enhanced:
            return .enhanced
        default:
            return .standard
        }
    }

    /// Premium/Enhanced 음성은 모두 포함, 3개 미만이면 Default로 채워서 최대 3개
    private func filterVoicesByQuality(_ voices: [TTSVoiceConfig]) -> [TTSVoiceConfig] {
        let premiumEnhanced = voices.filter { $0.quality == .premium || $0.quality == .enhanced }
        let standardVoices = voices.filter { $0.quality == .standard }

        if premiumEnhanced.count >= 3 {
            return premiumEnhanced.sorted { $0.quality > $1.quality }
        } else {
            let needed = 3 - premiumEnhanced.count
            let filledStandard = Array(standardVoices.prefix(needed))
            return (premiumEnhanced + filledStandard).sorted { $0.quality > $1.quality }
        }
    }
}
