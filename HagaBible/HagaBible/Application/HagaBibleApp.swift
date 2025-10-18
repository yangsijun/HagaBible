//
//  HagaBibleApp.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI
import SwiftData

@main
struct HagaBibleApp: App {
    init() {
        DIContainer.registerDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(DIContainer.shared.resolve(type: FontThemeManager.self).colorScheme)
        }
    }
}
