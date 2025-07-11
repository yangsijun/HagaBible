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
        
        do {
            let appDatabase = try AppDatabase()
            container.register(type: AppDatabase.self, component: appDatabase)
            print("✅ AppDatabase가 성공적으로 등록되었습니다.")
        } catch {
            // 데이터베이스 초기화 실패는 복구 불가능한 오류로 간주합니다.
            fatalError("🚨 AppDatabase 초기화에 실패했습니다: \(error)")
        }
        
        container.register(type: BibleRepository.self, component: DefaultBibleRepository(
            dbQueue: container.resolve(type: AppDatabase.self).dbQueue
        ))

        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
    }
}
