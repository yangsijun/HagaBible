//
//  DIContainer.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import Foundation
import OSLog
import SwiftData

final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    private var services: [String: Any] = [:]

    func register<Service>(type: Service.Type, component: Any) {
        let key = String(describing: type)
        services[key] = component
    }

    func resolve<Service>(type: Service.Type) -> Service {
        let key = String(describing: type)
        guard let component = services[key] as? Service else {
            fatalError("\(key)가 등록되지 않았습니다. 앱 시작점에서 등록했는지 확인하세요.")
        }
        return component
    }
}

extension DIContainer {
    static func registerDependencies() {
        let container = DIContainer.shared
        
        container.register(type: AppState.self, component: AppState())
        
        do {
            let bibleDatabaseService = try BibleDatabaseService()
            container.register(type: BibleDatabaseService.self, component: bibleDatabaseService)
            Logger.database.debug("BibleDatabaseService registered successfully")
        } catch {
            // 데이터베이스 초기화 실패는 복구 불가능한 오류로 간주합니다.
            fatalError("BibleDatabase 초기화에 실패했습니다: \(error)")
        }
        
        container.register(type: ODRDataSource.self, component: ODRDataSource())
        container.register(type: FileSystemDataSource.self, component: FileSystemDataSource())
        container.register(type: BibleFileRepository.self, component: DefaultBibleFileRepository())
        
//        guard let dbPool = container.resolve(type: BibleDatabaseService.self).dbPool else {
//            fatalError("BibleDatabaseService에서 dbPool을 얻지 못했습니다.")
//        }
        container.register(type: BibleRepository.self, component: DefaultBibleRepository(
//            dbPool: dbPool
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

        // TTS Dependencies
        let voiceProvider = AVVoiceProvider()
        container.register(type: VoiceProvider.self, component: voiceProvider)
        container.register(type: TTSSettingsRepository.self, component: DefaultTTSSettingsRepository())
        container.register(type: SpeechSynthesizer.self, component: AVSpeechSynthesizerAdapter())

        let ttsManager = TTSPlaybackManager(
            synthesizer: container.resolve(type: SpeechSynthesizer.self),
            settingsRepository: container.resolve(type: TTSSettingsRepository.self),
            voiceProvider: voiceProvider
        )
        container.register(type: TTSPlaybackManager.self, component: ttsManager)

        container.register(type: TTSViewModel.self, component: TTSViewModel(
            ttsManager: ttsManager,
            bibleReaderViewModel: container.resolve(type: BibleReaderViewModel.self)
        ))

        let schema = Schema([Recording.self, RecordingFolder.self, SearchHistory.self])
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
        
        container.register(type: SearchHistoryRepository.self, component: DefaultSearchHistoryRepository())
        
        container.register(type: SearchViewModel.self, component: SearchViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self),
            bibleReaderViewModel: container.resolve(type: BibleReaderViewModel.self),
            searchHistoryRepository: container.resolve(type: SearchHistoryRepository.self)
        ))
        
        container.register(type: FontThemeManager.self, component: FontThemeManager())
    }
    
    static func registerForPreview() {
        let container = DIContainer.shared
        
        container.register(type: AppState.self, component: AppState())
        
        container.register(type: BibleRepository.self, component: MockBibleRepository.shared)
        
        container.register(type: BibleActionService.self, component: BibleActionService())
        
        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))
        
        container.register(type: BibleNavigationViewModel.self, component: BibleNavigationViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))

        container.register(type: AudioService.self, component: AudioService())

        // TTS Dependencies
        let voiceProvider = AVVoiceProvider()
        container.register(type: VoiceProvider.self, component: voiceProvider)
        container.register(type: TTSSettingsRepository.self, component: DefaultTTSSettingsRepository())
        container.register(type: SpeechSynthesizer.self, component: AVSpeechSynthesizerAdapter())

        let ttsManager = TTSPlaybackManager(
            synthesizer: container.resolve(type: SpeechSynthesizer.self),
            settingsRepository: container.resolve(type: TTSSettingsRepository.self),
            voiceProvider: voiceProvider
        )
        container.register(type: TTSPlaybackManager.self, component: ttsManager)

        container.register(type: TTSViewModel.self, component: TTSViewModel(
            ttsManager: ttsManager,
            bibleReaderViewModel: container.resolve(type: BibleReaderViewModel.self)
        ))

        let schema = Schema([Recording.self, RecordingFolder.self, SearchHistory.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        
        container.register(type: SearchHistoryRepository.self, component: DefaultSearchHistoryRepository())
        
        container.register(type: SearchViewModel.self, component: SearchViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self),
            bibleReaderViewModel: container.resolve(type: BibleReaderViewModel.self),
            searchHistoryRepository: container.resolve(type: SearchHistoryRepository.self)
        ))
        
        container.register(type: FontThemeManager.self, component: FontThemeManager())
    }
}
