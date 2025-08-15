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

func getUIFontFromFontConfiguration(_ config: FontConfiguration, language: String) -> UIFont? {
    return UIFont(
        name: fontNamePairs[config.type[language] ?? .sans]?[config.style] ?? Pretendard.regular.rawValue,
        size: CGFloat(config.size)
    )
}
