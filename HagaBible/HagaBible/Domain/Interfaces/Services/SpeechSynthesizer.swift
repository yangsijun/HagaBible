//
//  SpeechSynthesizer.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// 음성 합성기 이벤트 델리게이트
protocol SpeechSynthesizerDelegate: AnyObject {
    /// 발화가 실제로 재생을 시작함 (오디오 출력이 시작된 시점)
    func speechDidStart()
    /// 현재 발화가 완료됨
    func speechDidFinish()
    /// 발화가 일시 정지됨
    func speechDidPause()
    /// 발화가 재개됨
    func speechDidContinue()
    /// 발화가 취소됨
    func speechDidCancel()

    /// 오디오 출력 라우트/포맷 변경(예: 블루투스 HFP→A2DP 전환)으로 엔진이 재시작되어
    /// 진행 중이던 발화의 스케줄 버퍼가 유실됨. 호출자가 현재 절을 재발화해 복구할 수 있다.
    func speechDidResetEngine()
}

extension SpeechSynthesizer {
    /// 기본 구현 — 별도 오디오 엔진을 구동하지 않는 구현체는 `isSpeaking`이 곧 실제 재생
    /// 여부이므로 그대로 폴백한다. AVAudioEngine 기반 구현만 엔진 실행 상태를 별도로 노출한다.
    var isActuallyPlaying: Bool { isSpeaking }
}

extension SpeechSynthesizerDelegate {
    /// 기본 구현 — 시작 콜백이 필요 없는 구현체를 위해 비워둔다.
    func speechDidStart() {}
    /// 기본 구현 — 엔진을 직접 구동하지 않는 구현체(예: AVSpeechSynthesizer 직접 호출)는
    /// 라우트 변경 시 재발화 복구가 필요 없으므로 비워둔다.
    func speechDidResetEngine() {}
}

/// 음성 합성기 추상화 프로토콜
protocol SpeechSynthesizer: AnyObject {
    /// 이벤트 델리게이트
    var delegate: SpeechSynthesizerDelegate? { get set }

    /// 현재 일시 정지 상태인지
    var isPaused: Bool { get }

    /// 현재 발화 중인지
    var isSpeaking: Bool { get }

    /// 오디오 엔진이 실제로 오디오를 출력하고 있는지.
    /// iOS가 (백그라운드 suspend 등으로) 오디오 세션을 내려버려 앱 상태만 "재생 중"으로
    /// 남고 소리는 나지 않는 경우를 구분하는 데 쓴다. 엔진을 직접 구동하지 않는 구현체는
    /// `isSpeaking`으로 폴백한다(기본 구현 참조).
    var isActuallyPlaying: Bool { get }

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

    /// 음성 캐시 초기화
    func clearVoiceCache()
}
