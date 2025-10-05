//
//  Theme.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

enum Theme: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var themeName: String { self.rawValue }
    var textColor: UIColor {
        switch self {
        case .system: return UIColor(Color("SystemTheme/textColor"))
        case .light: return UIColor(Color("LightTheme/textColor"))
        case .dark: return UIColor(Color("DarkTheme/textColor"))
        }
    }
    var verseNumberColor: UIColor {
        switch self {
        case .system: return UIColor(Color("SystemTheme/verseNumberColor"))
        case .light: return UIColor(Color("LightTheme/verseNumberColor"))
        case .dark: return UIColor(Color("DarkTheme/verseNumberColor"))
        }
    }
    var backgroundColor: UIColor {
        switch self {
        case .system: return UIColor(Color("SystemTheme/backgroundColor"))
        case .light: return UIColor(Color("LightTheme/backgroundColor"))
        case .dark: return UIColor(Color("DarkTheme/backgroundColor"))
        }
    }
}

#Preview {
    VStack {
        ForEach(Theme.allCases, id: \.self) { theme in
            HStack {
                Text("1")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: theme.verseNumberColor))
                Text(theme.themeName)
                    .foregroundStyle(Color(uiColor: theme.textColor))
            }
            .padding()
            .background(
                Color(theme.backgroundColor)
            )
        }
    }
}
