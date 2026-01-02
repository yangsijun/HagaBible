//
//  TTSVoiceConfig.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation

/// TTS 음성 설정 (플랫폼 독립적)
struct TTSVoiceConfig: Equatable, Codable, Identifiable {
    let identifier: String
    let name: String
    let language: String
    let quality: VoiceQuality

    var id: String { identifier }

    /// 음성 품질 등급
    enum VoiceQuality: Int, Codable, Comparable {
        case standard = 0
        case enhanced = 1
        case premium = 2

        static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var displayName: String {
            switch self {
            case .standard: return "Default"
            case .enhanced: return "Enhanced"
            case .premium: return "Premium"
            }
        }
    }

    /// 영국 영어인지 확인
    var isUKEnglish: Bool {
        language == "en-GB"
    }

    /// 미국 영어인지 확인
    var isUSEnglish: Bool {
        language == "en-US"
    }
}
