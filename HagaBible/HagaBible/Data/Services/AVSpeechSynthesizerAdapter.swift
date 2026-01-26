//
//  AVSpeechSynthesizerAdapter.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import AVFoundation

/// AVSpeechSynthesizer를 SpeechSynthesizer 프로토콜로 래핑하는 어댑터
@MainActor
class AVSpeechSynthesizerAdapter: NSObject, SpeechSynthesizer {
    weak var delegate: SpeechSynthesizerDelegate?

    private var synthesizer: AVSpeechSynthesizer
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    var isPaused: Bool { synthesizer.isPaused }
    var isSpeaking: Bool { synthesizer.isSpeaking }

    override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, voice: TTSVoiceConfig?, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = mapToAVVoice(voice)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        synthesizer.speak(utterance)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func recreate() {
        synthesizer.delegate = nil
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
    }

    // MARK: - Private Methods

    private func mapToAVVoice(_ config: TTSVoiceConfig?) -> AVSpeechSynthesisVoice? {
        guard let config = config else {
            return getAnyAvailableVoice()
        }

        // 캐시된 음성 객체가 있으면 재사용 (메인 스레드 블로킹 방지)
        if let cached = voiceCache[config.identifier] {
            return cached
        }

        let languageCode = config.language.isEmpty ? "ko-KR" : config.language

        // macOS Catalyst에서는 premium 음성이 작동하지 않음
        // compact 또는 eloquence 음성을 명시적으로 선택
        if PlatformHelper.isRunningOnMac {
            if let workingVoice = getMacOSWorkingVoice(for: languageCode) {
                voiceCache[config.identifier] = workingVoice
                return workingVoice
            }
            return getAnyAvailableVoice()
        }

        // iOS: identifier 기반 음성 사용
        if let voice = AVSpeechSynthesisVoice(identifier: config.identifier) {
            voiceCache[config.identifier] = voice
            return voice
        }

        // iOS에서 identifier로 찾지 못한 경우 language 기반 폴백
        if let languageVoice = AVSpeechSynthesisVoice(language: languageCode) {
            voiceCache[config.identifier] = languageVoice
            return languageVoice
        }

        return getAnyAvailableVoice()
    }

    /// 사용 가능한 아무 음성이나 반환 (최후의 폴백)
    private func getAnyAvailableVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices().first
    }

    /// macOS Catalyst에서 작동하는 음성 반환 (premium 음성 제외)
    private func getMacOSWorkingVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // 해당 언어의 음성 중 premium이 아닌 것 찾기
        // premium 음성은 macOS Catalyst에서 작동하지 않음
        let languageVoices = allVoices.filter { voice in
            voice.language == languageCode && !voice.identifier.contains(".premium.")
        }

        // compact 음성 우선 (품질이 가장 좋음)
        if let compactVoice = languageVoices.first(where: { $0.identifier.contains(".compact") }) {
            return compactVoice
        }

        // eloquence 음성
        if let eloquenceVoice = languageVoices.first(where: { $0.identifier.contains(".eloquence.") }) {
            return eloquenceVoice
        }

        // 그 외 non-premium 음성
        if let anyNonPremium = languageVoices.first {
            return anyNonPremium
        }

        // 해당 언어에 non-premium 음성이 없으면 아무 non-premium 음성
        return allVoices.first { !$0.identifier.contains(".premium.") }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AVSpeechSynthesizerAdapter: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.speechDidFinish()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.speechDidPause()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.speechDidContinue()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.speechDidCancel()
        }
    }
}
