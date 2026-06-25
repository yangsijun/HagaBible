//
//  DIContainer.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import Foundation
import OSLog
import SwiftData
import Supabase

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

    /// Non-fatal lookup for optional dependencies (e.g. sync, which isn't wired in
    /// the preview graph). Returns nil instead of crashing when unregistered.
    func resolveOptional<Service>(type: Service.Type) -> Service? {
        services[String(describing: type)] as? Service
    }
}

extension DIContainer {
    static func registerDependencies() {
        let container = DIContainer.shared
        
        container.register(type: AppState.self, component: AppState())
        
        container.register(type: NotificationService.self, component: NotificationService())

        do {
            let bibleDatabaseService = try BibleDatabaseService()
            container.register(type: BibleDatabaseService.self, component: bibleDatabaseService)
            Logger.database.debug("BibleDatabaseService registered successfully")
        } catch {
            // 데이터베이스 초기화 실패는 복구 불가능한 오류로 간주합니다.
            fatalError("BibleDatabase 초기화에 실패했습니다: \(error)")
        }
        
        do {
            let userDataDB = try UserDataDatabaseService()
            container.register(type: UserDataDatabaseService.self, component: userDataDB)
            Logger.database.debug("UserDataDatabaseService registered successfully")
        } catch {
            fatalError("UserData database initialisation failed: \(error)")
        }

        container.register(type: BookmarkRepository.self, component: DefaultBookmarkRepository())
        container.register(type: ReadingMarkRepository.self, component: DefaultReadingMarkRepository())

        // Cross-device sync (Supabase + Sign in with Apple). The client is always
        // built so the Account screen resolves a view model; it only does network
        // work once the user signs in and the anon key is configured.
        let supabaseClient = SupabaseClientProvider.make()
        let authService: AuthService = SupabaseAuthService(client: supabaseClient)
        container.register(type: AuthService.self, component: authService)
        let remoteSync: RemoteSyncDataSource = SupabaseRemoteSyncDataSource(client: supabaseClient)
        if let userDataPool = container.resolve(type: UserDataDatabaseService.self).dbPool {
            let syncEngine = SyncEngine(pool: userDataPool, remote: remoteSync)
            container.register(type: SyncEngine.self, component: syncEngine)
            container.register(
                type: SyncAccountViewModel.self,
                component: SyncAccountViewModel(authService: authService, syncEngine: syncEngine)
            )
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

        // In-app purchase store (StoreKit 2) + version acquisition use cases.
        registerBibleVersionStore(
            container: container,
            store: StoreKitBibleVersionStore(),
            fileRepository: container.resolve(type: BibleFileRepository.self)
        )

        container.register(type: BibleActionService.self, component: BibleActionService())

        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self),
            bookmarkRepository: container.resolve(type: BookmarkRepository.self)
        ))

        container.register(type: BibleNavigationViewModel.self, component: BibleNavigationViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))

        container.register(type: AudioService.self, component: AudioService())
        container.register(type: AudioSessionConfigurable.self, component: SystemAudioSessionConfigurator())
        container.register(type: RemoteCommandConfigurable.self, component: SystemRemoteCommandConfigurator())
        container.register(type: InterruptionObservable.self, component: NotificationCenterInterruptionObserver())
        container.register(type: RecordingStateProvider.self, component: AudioServiceRecordingStateProvider(
            audioServiceProvider: { container.resolve(type: AudioService.self) }
        ))

        // TTS Dependencies
        let voiceProvider = AVVoiceProvider()
        container.register(type: VoiceProvider.self, component: voiceProvider)
        container.register(type: TTSSettingsRepository.self, component: DefaultTTSSettingsRepository())
        // On iOS, render speech through AVAudioEngine so the app becomes the system
        // "Now Playing" app (Lock Screen / Control Center card). macOS Catalyst keeps
        // the proven direct-speak adapter.
        let speechSynthesizer: SpeechSynthesizer = PlatformHelper.isRunningOnMac
            ? AVSpeechSynthesizerAdapter()
            : AVAudioEngineSpeechSynthesizer()
        container.register(type: SpeechSynthesizer.self, component: speechSynthesizer)
        container.register(type: NowPlayingInfoCenterProtocol.self, component: SystemNowPlayingInfoCenter())

        let ttsManager = TTSPlaybackManager(
            synthesizer: container.resolve(type: SpeechSynthesizer.self),
            settingsRepository: container.resolve(type: TTSSettingsRepository.self),
            voiceProvider: voiceProvider,
            audioSessionConfigurator: container.resolve(type: AudioSessionConfigurable.self),
            remoteCommandConfigurator: container.resolve(type: RemoteCommandConfigurable.self),
            interruptionObservable: container.resolve(type: InterruptionObservable.self),
            recordingStateProvider: container.resolve(type: RecordingStateProvider.self),
            nowPlayingInfoCenter: container.resolve(type: NowPlayingInfoCenterProtocol.self)
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
            
        container.register(type: RecordingPlaybackManager.self, component: RecordingPlaybackManager(
            ttsManager: container.resolve(type: TTSPlaybackManager.self),
            interruptionObservable: container.resolve(type: InterruptionObservable.self)
        ))

        container.register(type: RecordingsViewModel.self, component: RecordingsViewModel(
            appState: container.resolve(type: AppState.self),
            audioService: container.resolve(type: AudioService.self),
            recordingRepository: container.resolve(type: RecordingRepository.self),
            playbackManager: container.resolve(type: RecordingPlaybackManager.self)
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

    /// Wires the in-app purchase store and its version-acquisition use cases +
    /// view model. Shared by the production and preview registration paths so the
    /// graph stays identical apart from the injected `store`/`fileRepository`.
    private static func registerBibleVersionStore(
        container: DIContainer,
        store: BibleVersionStore,
        fileRepository: BibleFileRepository
    ) {
        container.register(type: BibleVersionStore.self, component: store)

        let loadCatalogUseCase: LoadBibleVersionCatalogUseCase = DefaultLoadBibleVersionCatalogUseCase(
            bibleRepository: container.resolve(type: BibleRepository.self),
            store: store
        )
        container.register(type: LoadBibleVersionCatalogUseCase.self, component: loadCatalogUseCase)

        let acquireUseCase: AcquireBibleVersionUseCase = DefaultAcquireBibleVersionUseCase(
            store: store,
            fileRepository: fileRepository
        )
        container.register(type: AcquireBibleVersionUseCase.self, component: acquireUseCase)

        let restoreUseCase: RestorePurchasesUseCase = DefaultRestorePurchasesUseCase(store: store)
        container.register(type: RestorePurchasesUseCase.self, component: restoreUseCase)

        container.register(type: BibleVersionStoreViewModel.self, component: BibleVersionStoreViewModel(
            loadCatalogUseCase: loadCatalogUseCase,
            acquireUseCase: acquireUseCase,
            restoreUseCase: restoreUseCase,
            fileRepository: fileRepository
        ))
    }

    static func registerForPreview() {
        let container = DIContainer.shared

        container.register(type: AppState.self, component: AppState())

        container.register(type: NotificationService.self, component: NotificationService())

        container.register(type: BibleRepository.self, component: MockBibleRepository.shared)

        // In-app purchase store (mocked) + version acquisition use cases.
        registerBibleVersionStore(
            container: container,
            store: MockBibleVersionStore(),
            fileRepository: MockBibleFileRepository()
        )

        container.register(type: BibleActionService.self, component: BibleActionService())

        container.register(type: BookmarkRepository.self, component: MockBookmarkRepository())
        container.register(type: ReadingMarkRepository.self, component: MockReadingMarkRepository())

        container.register(type: BibleReaderViewModel.self, component: BibleReaderViewModel(
            appState: container.resolve(type: AppState.self),
            bibleRepository: container.resolve(type: BibleRepository.self),
            bookmarkRepository: container.resolve(type: BookmarkRepository.self)
        ))

        container.register(type: BibleNavigationViewModel.self, component: BibleNavigationViewModel(
            bibleRepository: container.resolve(type: BibleRepository.self)
        ))

        container.register(type: AudioService.self, component: AudioService())
        container.register(type: AudioSessionConfigurable.self, component: SystemAudioSessionConfigurator())
        container.register(type: RemoteCommandConfigurable.self, component: SystemRemoteCommandConfigurator())
        container.register(type: InterruptionObservable.self, component: NotificationCenterInterruptionObserver())
        container.register(type: RecordingStateProvider.self, component: AudioServiceRecordingStateProvider(
            audioServiceProvider: { container.resolve(type: AudioService.self) }
        ))

        // TTS Dependencies
        let voiceProvider = AVVoiceProvider()
        container.register(type: VoiceProvider.self, component: voiceProvider)
        container.register(type: TTSSettingsRepository.self, component: DefaultTTSSettingsRepository())
        // On iOS, render speech through AVAudioEngine so the app becomes the system
        // "Now Playing" app (Lock Screen / Control Center card). macOS Catalyst keeps
        // the proven direct-speak adapter.
        let speechSynthesizer: SpeechSynthesizer = PlatformHelper.isRunningOnMac
            ? AVSpeechSynthesizerAdapter()
            : AVAudioEngineSpeechSynthesizer()
        container.register(type: SpeechSynthesizer.self, component: speechSynthesizer)
        container.register(type: NowPlayingInfoCenterProtocol.self, component: SystemNowPlayingInfoCenter())

        let ttsManager = TTSPlaybackManager(
            synthesizer: container.resolve(type: SpeechSynthesizer.self),
            settingsRepository: container.resolve(type: TTSSettingsRepository.self),
            voiceProvider: voiceProvider,
            audioSessionConfigurator: container.resolve(type: AudioSessionConfigurable.self),
            remoteCommandConfigurator: container.resolve(type: RemoteCommandConfigurable.self),
            interruptionObservable: container.resolve(type: InterruptionObservable.self),
            recordingStateProvider: container.resolve(type: RecordingStateProvider.self),
            nowPlayingInfoCenter: container.resolve(type: NowPlayingInfoCenterProtocol.self)
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
        
        container.register(type: RecordingPlaybackManager.self, component: RecordingPlaybackManager(
            ttsManager: container.resolve(type: TTSPlaybackManager.self),
            interruptionObservable: container.resolve(type: InterruptionObservable.self)
        ))

        container.register(type: RecordingsViewModel.self, component: RecordingsViewModel(
            appState: container.resolve(type: AppState.self),
            audioService: container.resolve(type: AudioService.self),
            recordingRepository: container.resolve(type: RecordingRepository.self),
            playbackManager: container.resolve(type: RecordingPlaybackManager.self)
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
