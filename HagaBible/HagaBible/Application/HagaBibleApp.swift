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
        registerDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(DIContainer.shared.resolve(type: FontThemeManager.self).colorScheme)
        }
    }
    
    private func registerDependencies() {
        let container = DIContainer.shared
        
        container.register(type: AppState.self, component: AppState())
        
        do {
            let appDatabase = try AppDatabase()
            container.register(type: AppDatabase.self, component: appDatabase)
#if DEBUG
            print("✅ AppDatabase가 성공적으로 등록되었습니다.")
#endif
        } catch {
            // 데이터베이스 초기화 실패는 복구 불가능한 오류로 간주합니다.
            fatalError("🚨 AppDatabase 초기화에 실패했습니다: \(error)")
        }
        
        container.register(type: BibleRepository.self, component: DefaultBibleRepository(
            dbPool: container.resolve(type: AppDatabase.self).dbPool
        ))
        
        container.register(type: BibleActionService.self, component: BibleActionService())

        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
        
        container.register(type: BibleNavigationViewModel.self, component: BibleNavigationViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
        
        container.register(type: AudioService.self, component: AudioService())
        
        let schema = Schema([Recording.self, RecordingFolder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        guard let modelContainer = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("ModelContainer 생성에 실패했습니다.")
        }
        container.register(type: ModelContainer.self, component: modelContainer)
        
        container.register(type: RecordingRepository.self, component: DefaultRecordingRepository())
            
        container.register(type: RecordingsViewModel.self, component: RecordingsViewModel(
            appState: container.resolve(type: AppState.self),
            audioService: container.resolve(type: AudioService.self),
            recordingRepository: container.resolve(type: RecordingRepository.self)
        ))
        
        container.register(type: SearchViewModel.self, component: SearchViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self),
            bibleReaderViewModel: container.resolve(type: BibleReaderViewModel.self)
        ))
        
        container.register(type: FontThemeManager.self, component: FontThemeManager())
    }
}
