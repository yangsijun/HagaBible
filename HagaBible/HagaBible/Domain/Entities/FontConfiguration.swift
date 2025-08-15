//
//  FontConfiguration.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

enum FontType: String, CaseIterable {
    case sans = "Pretendard"
    case serif = "MaruBuriot"
}

enum FontStyle: String {
    case regular = "Regular"
    case semiBold = "SemiBold"
    case bold = "Bold"
}

enum TextAlignmentType: String {
    case natural = "natural"
    case justified = "justified"
}

enum LineBreakMode: String {
    case byWordWrapping = "byWordWrapping"
    case byCharWrapping = "byCharWrapping"
}

struct FontConfiguration {
    var type: FontType = .sans
    var style: FontStyle = .regular
    var size: Int = 20
    var alignment: TextAlignmentType = .natural
    var lineSpacing: Int = 0
}
