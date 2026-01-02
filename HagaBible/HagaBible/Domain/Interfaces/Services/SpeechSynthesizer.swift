//
//  SpeechSynthesizer.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// 음성 합성기 이벤트 델리게이트
protocol SpeechSynthesizerDelegate: AnyObject {
    /// 현재 발화가 완료됨
    func speechDidFinish()
    /// 발화가 일시 정지됨
    func speechDidPause()
    /// 발화가 재개됨
    func speechDidContinue()
    /// 발화가 취소됨
    func speechDidCancel()
}

/// 음성 합성기 추상화 프로토콜
protocol SpeechSynthesizer: AnyObject {
    /// 이벤트 델리게이트
    var delegate: SpeechSynthesizerDelegate? { get set }

    /// 현재 일시 정지 상태인지
    var isPaused: Bool { get }

    /// 현재 발화 중인지
    var isSpeaking: Bool { get }

    /// 텍스트를 음성으로 읽기
    /// - Parameters:
    ///   - text: 읽을 텍스트
    ///   - voice: 사용할 음성 설정 (nil이면 시스템 기본값)
    ///   - rate: 읽기 속도
    func speak(text: String, voice: TTSVoiceConfig?, rate: Float)

    /// 발화 일시 정지
    func pause()

    /// 발화 재개
    func resume()

    /// 발화 즉시 중지
    func stop()

    /// 합성기를 새로 생성 (클린 상태 보장)
    func recreate()
}
