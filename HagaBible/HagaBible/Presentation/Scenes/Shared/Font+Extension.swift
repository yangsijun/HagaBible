//
//  Font+Extension.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import Foundation
import UIKit
import SwiftUI

enum Pretendard: String {
    case black = "Pretendard-Black"
    case extraBold = "Pretendard-ExtraBold"
    case bold = "Pretendard-Bold"
    case semiBold = "Pretendard-SemiBold"
    case medium = "Pretendard-Medium"
    case regular = "Pretendard-Regular"
    case light = "Pretendard-Light"
    case extraLight = "Pretendard-ExtraLight"
    case thin = "Pretendard-Thin"
}

enum MaruBuri: String {
    case bold = "MaruBuriot-Bold"
    case semiBold = "MaruBuriot-SemiBold"
    case regular = "MaruBuriot-Regular"
    case light = "MaruBuriot-Light"
    case extraLight = "MaruBuriot-ExtraLight"
}

extension UIFont {
    static func pretendard(style: Pretendard = .regular, size: CGFloat) -> UIFont {
        return UIFont(name: style.rawValue, size: size) ?? .systemFont(ofSize: size)
    }
    
    static func maruBuri(style: MaruBuri = .regular, size: CGFloat) -> UIFont {
        return UIFont(name: style.rawValue, size: size) ?? .systemFont(ofSize: size)
    }
}

extension Font {
    static func pretendard(style: Pretendard = .regular, size: CGFloat) -> Font {
        return .custom(style.rawValue, size: size)
    }
    
    static func maruBuri(style: MaruBuri = .regular, size: CGFloat) -> Font {
        return .custom(style.rawValue, size: size)
    }
}
