//
//  FontConfiguration.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

enum FontType: String, Codable, CaseIterable {
    case sans = "Pretendard"
    case serif = "MaruBuriot"
}

enum FontStyle: String, Codable, CaseIterable {
    case regular = "Regular"
    case semiBold = "SemiBold"
    case bold = "Bold"
}

enum CodableTextAlignment: String, Codable {
    case left
    case center
    case right
    case justified
    case natural

    // NSTextAlignment를 CodableTextAlignment로 변환하는 초기화 메서드
    init(_ alignment: NSTextAlignment) {
        switch alignment {
        case .left: self = .left
        case .center: self = .center
        case .right: self = .right
        case .justified: self = .justified
        case .natural: self = .natural
        @unknown default: self = .natural
        }
    }

    // 현재 값을 다시 NSTextAlignment로 변환해주는 연산 프로퍼티
    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        case .natural: return .natural
        }
    }
}

struct FontConfiguration: Codable, Equatable {
    var type: [String: FontType] = [
        "English": .sans,
        "Korean": .serif,
    ]
    var style: FontStyle = .regular
    var size: Int = 20
    var alignment: [String: CodableTextAlignment] = [
        "English": .natural,
        "Korean": .justified,
    ]
    
    var lineSpacing: Int = 0
    
    static let defaultFontConfiguration: FontConfiguration = FontConfiguration(
        type: [
            "English": .sans,
            "Korean": .serif,
        ],
        style: .regular,
        size: 20,
        alignment: [
            "English": .natural,
            "Korean": .justified,
        ],
        lineSpacing: 0
    )
}

