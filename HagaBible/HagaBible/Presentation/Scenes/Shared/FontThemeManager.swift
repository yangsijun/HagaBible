//
//  FontThemeManager.swift
//  HagaBible
//
//  Created by 양시준 on 8/15/25.
//

import SwiftUI

@Observable
class FontThemeManager {
    var fontConfiguration: FontConfiguration = defaultFontConfiguration
    var theme: Theme = .system
    
    init(fontConfiguration: FontConfiguration, theme: Theme) {
        self.fontConfiguration = fontConfiguration
        self.theme = theme
    }
}
