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
        // The id lets the reader's "New Window" action open another instance of this group
        // (`openWindow(id:)`). Each window gets its own `RootView` and `WindowState`.
        WindowGroup(id: "main") {
            RootView()
        }
    }
}
