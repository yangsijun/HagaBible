//
//  FontConfiguration.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

enum FontType: String, CaseIterable {
    case sans = "Pretendard"
    case serif = "MaruBuriot"
}

enum FontStyle: String {
    case regular = "Regular"
    case semiBold = "SemiBold"
    case bold = "Bold"
}

struct FontConfiguration {
    var type: [String: FontType] = [
        "English": .sans,
        "Korean": .serif,
    ]
    var style: FontStyle = .regular
    var size: Int = 20
    var alignment: [String: NSTextAlignment] = [
        "English": .natural,
        "Korean": .justified,
    ]
    
    var lineSpacing: Int = 0
}

let defaultFontConfiguration: FontConfiguration = FontConfiguration(
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
