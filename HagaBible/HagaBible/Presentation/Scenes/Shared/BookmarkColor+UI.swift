//
//  BookmarkColor+UI.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import SwiftUI

extension BookmarkColor {
    /// Hex color string for UI rendering
    var hex: String {
        switch self {
        case .yellow: return "#FFD60A"
        case .blue:   return "#0A84FF"
        case .green:  return "#30D158"
        case .pink:   return "#FF375F"
        case .orange: return "#FF9F0A"
        }
    }

    /// SwiftUI Color for UI rendering
    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color(red: 1.0,  green: 0.839, blue: 0.039)
        case .blue:   return Color(red: 0.039, green: 0.518, blue: 1.0)
        case .green:  return Color(red: 0.188, green: 0.820, blue: 0.345)
        case .pink:   return Color(red: 1.0,  green: 0.216, blue: 0.373)
        case .orange: return Color(red: 1.0,  green: 0.624, blue: 0.039)
        }
    }
}
