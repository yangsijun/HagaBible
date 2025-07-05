//
//  HagaBibleApp.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

@main
struct HagaBibleApp: App {
    init() {
        registerDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
    
    private func registerDependencies() {
        let container = DIContainer.shared

        container.register(type: BibleRepository.self, component: MockBibleRepositoryImpl())

        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
    }
}
