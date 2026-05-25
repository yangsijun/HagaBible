import Testing
import Foundation
import MediaPlayer
@testable import HagaBible

@Suite("TTS Now Playing Sync Regression Tests")
struct TTSPlaybackManagerNowPlayingSyncTests {

    @Test("TTSPlaybackManager init accepts fake side-effect dependencies")
    @MainActor
    func initAcceptsFakeSideEffectDependencies() {
        let remoteCommandConfigurator = StubRemoteCommandConfigurator()
        let interruptionObservable = StubInterruptionObservable()
        let audioSessionConfigurator = StubAudioSessionConfigurator()

        let manager = TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: audioSessionConfigurator,
            remoteCommandConfigurator: remoteCommandConfigurator,
            interruptionObservable: interruptionObservable,
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: SpyNowPlayingInfoCenter()
        )

        #expect(manager.playbackState == .idle)
        #expect(remoteCommandConfigurator.configureCallCount == 1)
        #expect(interruptionObservable.addObserverCallCount == 1)
        #expect(audioSessionConfigurator.activateCallCount == 0)
    }

    @Test("startReading uses injected recording state provider")
    @MainActor
    func startReadingUsesInjectedRecordingStateProvider() async {
        let synthesizer = StubSpeechSynthesizer()
        let audioSessionConfigurator = StubAudioSessionConfigurator()
        let manager = TTSPlaybackManager(
            synthesizer: synthesizer,
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: audioSessionConfigurator,
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: true),
            nowPlayingInfoCenter: SpyNowPlayingInfoCenter()
        )

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        #expect(synthesizer.speakCallCount == 0)
        #expect(audioSessionConfigurator.activateCallCount == 0)
    }

    @Test("startReading keeps manager and Now Playing state in sync")
    @MainActor
    func startReadingKeepsPlaybackStateInSync() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = makeManager(nowPlayingInfoCenter: spy)

        manager.startReading(verses: [sampleVerse()], language: "Korean")

        #expect(manager.playbackState == .playing)

        await settleMainActorTasks()

        #expect(spy.playbackStateWrites.contains(.playing))
    }

    @Test("pause keeps manager and Now Playing state in sync")
    @MainActor
    func pauseKeepsPlaybackStateInSync() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = makeManager(nowPlayingInfoCenter: spy)

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.pause()

        #expect(manager.playbackState == .paused)
        #expect(spy.playbackStateWrites.contains(.paused))
        #expect(spy.playbackStateWrites.last == .paused)
    }

    @Test("resume keeps manager and Now Playing state in sync")
    @MainActor
    func resumeKeepsPlaybackStateInSync() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = makeManager(nowPlayingInfoCenter: spy)

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()
        manager.pause()
        manager.resume()

        #expect(manager.playbackState == .playing)
        #expect(spy.playbackStateWrites.contains(.paused))
        #expect(spy.playbackStateWrites.last == .playing)
    }

    @Test("stop resets app state and stops Now Playing before clearing info")
    @MainActor
    func stopKeepsPlaybackStateInSync() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = makeManager(nowPlayingInfoCenter: spy)

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.stop()

        #expect(manager.playbackState == .idle)

        await settleMainActorTasks()

        #expect(spy.clearNowPlayingInfoCallCount >= 1)

        let clearIndex = spy.recordedCalls.lastIndex { call in
            if case .clearNowPlayingInfo = call { return true }
            return false
        }
        let stoppedIndex = spy.recordedCalls.lastIndex { call in
            if case .setPlaybackState(.stopped) = call { return true }
            return false
        }

        #expect(clearIndex != nil)
        #expect(stoppedIndex != nil)

        guard let clearIndex, let stoppedIndex else {
            return
        }

        #expect(stoppedIndex < clearIndex)

        if clearIndex > 0 {
            switch spy.recordedCalls[clearIndex - 1] {
            case .setPlaybackState(let state):
                #expect(state == .stopped)
            default:
                #expect(Bool(false))
            }
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Now playing writes flow through injected facade in call order")
    @MainActor
    func nowPlayingWritesFlowThroughFacade() async throws {
        let spy = SpyNowPlayingInfoCenter()
        let manager = TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: StubAudioSessionConfigurator(),
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: spy
        )

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.pause()
        manager.stop()
        await settleMainActorTasks()

        // startReading defers to speakCurrentVerse (one info update), so the
        // expected sequence is 6 writes — not a redundant double-update on start.
        #expect(spy.nowPlayingInfoWrites.count == 2)
        #expect(spy.playbackStateWrites.map(\.rawValue) == [
            MPNowPlayingPlaybackState.playing.rawValue,
            MPNowPlayingPlaybackState.paused.rawValue,
            MPNowPlayingPlaybackState.stopped.rawValue
        ])
        #expect(spy.clearNowPlayingInfoCallCount == 1)

        // Require the exact count before indexing: a future regression then fails
        // this assertion instead of trapping out-of-range and killing the process.
        try #require(spy.recordedCalls.count == 6)

        // 1. startReading async Task → speakCurrentVerse → updateNowPlayingInfo (playing)
        switch spy.recordedCalls[0] {
        case .updateNowPlayingInfo(let info):
            #expect(info[MPMediaItemPropertyTitle] as? String == "Genesis 1")
            #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0)
        default:
            #expect(Bool(false))
        }

        switch spy.recordedCalls[1] {
        case .setPlaybackState(let state):
            #expect(state.rawValue == MPNowPlayingPlaybackState.playing.rawValue)
        default:
            #expect(Bool(false))
        }

        // 2. pause → syncNowPlayingState → updateNowPlayingInfo (paused)
        switch spy.recordedCalls[2] {
        case .updateNowPlayingInfo(let info):
            #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0.0)
        default:
            #expect(Bool(false))
        }

        switch spy.recordedCalls[3] {
        case .setPlaybackState(let state):
            #expect(state.rawValue == MPNowPlayingPlaybackState.paused.rawValue)
        default:
            #expect(Bool(false))
        }

        // 3. stop async Task → syncNowPlayingState(withInfo: false) → setPlaybackState(.stopped)
        switch spy.recordedCalls[4] {
        case .setPlaybackState(let state):
            #expect(state.rawValue == MPNowPlayingPlaybackState.stopped.rawValue)
        default:
            #expect(Bool(false))
        }

        // 4. stop async Task → clearNowPlayingInfo
        switch spy.recordedCalls[5] {
        case .clearNowPlayingInfo:
            #expect(Bool(true))
        default:
            #expect(Bool(false))
        }
    }

    @Test("switchChapter(forcePlay: false) keeps paused manager and now playing state paused")
    @MainActor
    func switchChapterWithoutForcePlayPreservesPausedState() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: StubAudioSessionConfigurator(),
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: spy
        )

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.pause()
        manager.switchChapter(verses: [sampleVerse(chapter: 2)], language: "Korean", forcePlay: false)
        await settleMainActorTasks()

        #expect(manager.playbackState == .paused)
        #expect(spy.playbackStateWrites.last?.rawValue == MPNowPlayingPlaybackState.paused.rawValue)
    }

    @Test("speechDidFinish at end of chapter keeps now playing paused during wait window")
    @MainActor
    func speechDidFinishAtEndOfChapterSetsPausedNowPlayingState() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: StubAudioSessionConfigurator(),
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: spy
        )

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.speechDidFinish()
        await settleMainActorTasks()

        #expect(manager.playbackState == .paused)
        #expect(spy.playbackStateWrites.last?.rawValue == MPNowPlayingPlaybackState.paused.rawValue)
        #expect(spy.nowPlayingInfoWrites.last?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0.0)
    }

    @Test("rapid pause resume pause leaves manager and now playing aligned")
    @MainActor
    func rapidPauseResumePauseLeavesFinalStatePaused() async {
        let spy = SpyNowPlayingInfoCenter()
        let manager = TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: StubAudioSessionConfigurator(),
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: spy
        )

        manager.startReading(verses: [sampleVerse()], language: "Korean")
        await settleMainActorTasks()

        manager.pause()
        manager.resume()
        manager.pause()
        await settleMainActorTasks()

        #expect(manager.playbackState == .paused)
        #expect(spy.playbackStateWrites.last?.rawValue == MPNowPlayingPlaybackState.paused.rawValue)
    }

    @MainActor
    private func settleMainActorTasks() async {
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    private func makeManager(
        nowPlayingInfoCenter: SpyNowPlayingInfoCenter
    ) -> TTSPlaybackManager {
        TTSPlaybackManager(
            synthesizer: StubSpeechSynthesizer(),
            settingsRepository: StubTTSSettingsRepository(),
            voiceProvider: StubVoiceProvider(),
            audioSessionConfigurator: StubAudioSessionConfigurator(),
            remoteCommandConfigurator: StubRemoteCommandConfigurator(),
            interruptionObservable: StubInterruptionObservable(),
            recordingStateProvider: StubRecordingStateProvider(isRecording: false),
            nowPlayingInfoCenter: nowPlayingInfoCenter
        )
    }

    private func sampleVerse(chapter: Int = 1, verse: Int = 1) -> BibleVerse {
        BibleVerse(
            bookCode: "GEN",
            bookName: "Genesis",
            bookOrder: 1,
            chapter: chapter,
            verse: verse,
            verseText: "In the beginning",
            versionCode: "KRV"
        )
    }
}

@MainActor
private final class StubSpeechSynthesizer: SpeechSynthesizer {
    weak var delegate: SpeechSynthesizerDelegate?
    var isPaused = false
    var isSpeaking = false
    private(set) var speakCallCount = 0

    func speak(text: String, voice: TTSVoiceConfig?, rate: Float) {
        speakCallCount += 1
        isSpeaking = true
    }

    func pause() {
        isPaused = true
        isSpeaking = false
    }

    func resume() {
        isPaused = false
        isSpeaking = true
    }

    func stop() {
        isPaused = false
        isSpeaking = false
    }

    func recreate() {}
    func clearVoiceCache() {}
}

@MainActor
private final class StubTTSSettingsRepository: TTSSettingsRepository {
    private var settings = TTSSettings.default

    func loadSettings() -> TTSSettings {
        settings
    }

    func saveSettings(_ settings: TTSSettings) {
        self.settings = settings
    }
}

private struct StubVoiceProvider: VoiceProvider {
    func availableVoices(for language: String) -> [TTSVoiceConfig] { [] }
    func voice(for identifier: String) -> TTSVoiceConfig? { nil }
    func defaultVoice(for language: String) -> TTSVoiceConfig? { nil }
    func refreshVoices() {}
}

private final class StubAudioSessionConfigurator: AudioSessionConfigurable {
    private(set) var activateCallCount = 0
    private(set) var deactivateCallCount = 0

    func activatePlaybackSession() throws {
        activateCallCount += 1
    }

    func deactivatePlaybackSession() throws {
        deactivateCallCount += 1
    }
}

private final class StubRemoteCommandConfigurator: RemoteCommandConfigurable {
    private(set) var configureCallCount = 0

    func configureCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onNextTrack: @escaping () -> Void,
        onPreviousTrack: @escaping () -> Void
    ) {
        configureCallCount += 1
    }
}

private final class StubInterruptionObservable: InterruptionObservable {
    private(set) var addObserverCallCount = 0
    private(set) var removeObserverCallCount = 0

    @discardableResult
    func addInterruptionObserver(handler: @escaping (Notification) -> Void) -> NSObjectProtocol {
        addObserverCallCount += 1
        return NSObject()
    }

    func removeObserver(_ observer: NSObjectProtocol) {
        removeObserverCallCount += 1
    }
}

private struct StubRecordingStateProvider: RecordingStateProvider {
    let isRecording: Bool
}
