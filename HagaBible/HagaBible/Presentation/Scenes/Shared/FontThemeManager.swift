//
//  FontThemeManager.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

@Observable
class FontThemeManager {
    var theme: Theme = .system {
        didSet {
            saveTheme()
        }
    }
    var fontConfiguration: FontConfiguration = FontConfiguration.defaultFontConfiguration {
        didSet {
            saveFontConfiguration()
        }
    }
    
    var colorScheme: ColorScheme? {
        switch theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    init() {
        loadTheme()
        loadFontConfiguration()
    }
    
    private let themeKey = "theme"
    private func saveTheme() {
        if let encodedData = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(encodedData, forKey: themeKey)
        }
    }
    private func loadTheme() {
        if let savedData = UserDefaults.standard.data(forKey: themeKey),
           let decodedState = try? JSONDecoder().decode(Theme.self, from: savedData) {
            self.theme = decodedState
        }
    }
    
    
    private let fontConfigurationKey = "fontConfiguration"
    private func saveFontConfiguration() {
        if let encodedData = try? JSONEncoder().encode(fontConfiguration) {
            UserDefaults.standard.set(encodedData, forKey: fontConfigurationKey)
        }
    }
    private func loadFontConfiguration() {
        if let savedData = UserDefaults.standard.data(forKey: fontConfigurationKey),
           let decodedState = try? JSONDecoder().decode(FontConfiguration.self, from: savedData) {
            self.fontConfiguration = decodedState
        }
    }
}
