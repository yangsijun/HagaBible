//
//  FontUtils.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

func getUIFontFromFontConfiguration(_ config: FontConfiguration) -> UIFont {
    switch config.type {
    case .sans:
        switch config.style {
        case .regular:
            return .pretendard(style: .regular, size: CGFloat(config.size))
        case .bold:
            return .pretendard(style: .bold, size: CGFloat(config.size))
        case .semiBold:
            return .pretendard(style: .semiBold, size: CGFloat(config.size))
        }
    case .serif:
        switch config.style {
        case .regular:
            return .maruBuri(style: .regular, size: CGFloat(config.size))
        case .semiBold:
            return .maruBuri(style: .semiBold, size: CGFloat(config.size))
        case .bold:
            return .maruBuri(style: .bold, size: CGFloat(config.size))
        }
    }
}
