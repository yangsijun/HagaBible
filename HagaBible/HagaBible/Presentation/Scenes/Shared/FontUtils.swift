//
//  FontUtils.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

let fontNamePairs: [FontType: [FontStyle: String]] = [
    .sans: [
        .regular: Pretendard.regular.rawValue,
        .semiBold: Pretendard.semiBold.rawValue,
        .bold: Pretendard.bold.rawValue
    ],
    .serif: [
        .regular: MaruBuri.regular.rawValue,
        .semiBold: MaruBuri.semiBold.rawValue,
        .bold: MaruBuri.bold.rawValue
    ]
]

func getUIFontFromFontConfiguration(_ config: FontConfiguration) -> UIFont {
    return UIFont(name: (fontNamePairs[config.type]?[config.style]) ?? "", size: CGFloat(config.size)) ?? .systemFont(ofSize: CGFloat(config.size))
//    switch config.type {
//    case .sans:
//        switch config.style {
//        case .regular:
//            return .pretendard(style: .regular, size: CGFloat(config.size))
//        case .bold:
//            return .pretendard(style: .bold, size: CGFloat(config.size))
//        case .semiBold:
//            return .pretendard(style: .semiBold, size: CGFloat(config.size))
//        }
//    case .serif:
//        switch config.style {
//        case .regular:
//            return .maruBuri(style: .regular, size: CGFloat(config.size))
//        case .semiBold:
//            return .maruBuri(style: .semiBold, size: CGFloat(config.size))
//        case .bold:
//            return .maruBuri(style: .bold, size: CGFloat(config.size))
//        }
//    }
}

func getNSAlignmentFromFontConfiguration(_ config: FontConfiguration) -> NSTextAlignment {
    switch config.alignment {
    case .natural:
        return .natural
    case .justified:
        return .justified
    }
}

//func getNSLineBreakModeFromFontConfiguration(_ config: FontConfiguration) -> NSLineBreakMode {
//    switch config.lineBreakMode {
//    case .byWordWrapping:
//        return .byWordWrapping
//    case .byCharWrapping:
//        return .byCharWrapping
//    }
//}
