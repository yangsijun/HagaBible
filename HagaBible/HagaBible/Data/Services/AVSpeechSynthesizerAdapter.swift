//
//  AVSpeechSynthesizerAdapter.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation
import AVFoundation

/// AVSpeechSynthesizer를 SpeechSynthesizer 프로토콜로 래핑하는 어댑터
@MainActor
class AVSpeechSynthesizerAdapter: NSObject, SpeechSynthesizer {
    weak var delegate: SpeechSynthesizerDelegate?

    private var synthesizer: AVSpeechSynthesizer

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
            return nil
        }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == config.identifier }
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
