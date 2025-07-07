//
//  FontConfiguration.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

enum FontType: String {
    case sans = "Pretendard-Regular"
    case serif = "MaruBuriot-Regular"
}

enum FontStyle: String {
    case regular = "Regular"
    case semiBold = "SemiBold"
    case bold = "Bold"
}

struct FontConfiguration {
    var type: FontType = .sans
    var style: FontStyle = .regular
    var size: Float = 17
}
