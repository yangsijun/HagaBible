//
//  TTSPlaybackManager.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//  Refactored on 1/3/26 for Clean Architecture.
//

import AVFoundation
import MediaPlayer
import OSLog

@MainActor
@Observable
class TTSPlaybackManager: NSObject {
    // MARK: - Public Properties

    private(set) var playbackState: TTSPlaybackState = .idle
    private(set) var currentVerseIndex: Int = 0
    private(set) var verses: [BibleVerse] = []
    private(set) var bookName: String = ""
    private(set) var bookCode: String = ""
    private(set) var chapterNum: Int = 0
    private(set) var currentLanguage: String = "Korean"

    var speechRate: Float {
        get { settings.speechRate }
        set { updateSpeechRate(newValue) }
    }

    var selectedKoreanVoice: TTSVoiceConfig? {
        guard let id = settings.koreanVoiceIdentifier else { return nil }
        return voiceProvider.voice(for: id)
    }

    var selectedEnglishVoice: TTSVoiceConfig? {
        guard let id = settings.englishVoiceIdentifier else { return nil }
        return voiceProvider.voice(for: id)
    }

    var koreanVoices: [TTSVoiceConfig] {
        voiceProvider.availableVoices(for: "Korean")
    }

    var englishVoices: [TTSVoiceConfig] {
        voiceProvider.availableVoices(for: "English")
    }

    var totalVerses: Int { verses.count }

    /// Chapter title for display, with the Korean counter noun appended when a Korean
    /// version is active: "예레미야 1장" (or "시편 1편" for Psalms). Non-Korean versions get
    /// an empty counter noun, so this stays "Genesis 1".
    var chapterTitle: String {
        let counterNoun = getChapterCounterNoun(bookCode: bookCode, versionLanguage: currentLanguage)
        return "\(bookName) \(chapterNum)\(counterNoun)"
    }

    var currentVoice: TTSVoiceConfig? {
        if currentLanguage == "Korean" {
            return selectedKoreanVoice ?? voiceProvider.defaultVoice(for: "Korean")
        } else {
            return selectedEnglishVoice ?? voiceProvider.defaultVoice(for: "English")
        }
    }

    /// Callback when chapter finishes - called after delay to trigger next chapter
    var onChapterFinished: (() -> Void)?

    // MARK: - Dependencies

    private let synthesizer: SpeechSynthesizer
    private let settingsRepository: TTSSettingsRepository
    private let voiceProvider: VoiceProvider
    private let audioSessionConfigurator: AudioSessionConfigurable
    private let remoteCommandConfigurator: RemoteCommandConfigurable
    private let interruptionObservable: InterruptionObservable
    private let recordingStateProvider: RecordingStateProvider
    private let nowPlayingInfoCenter: NowPlayingInfoCenterProtocol

    // MARK: - Internal State

    private var settings: TTSSettings
    private var isRestarting = false
    private var restartTask: Task<Void, Never>?
    private var nextChapterTask: Task<Void, Never>?
    private var isSynthesizerBusy = false
    private var operationGeneration: Int = 0
    private var isPauseRequested = false
    private var interruptionObserverToken: NSObjectProtocol?

    /// Wall-clock anchor for the chapter's elapsed time. Paired with the playback
    /// rate so iOS reflects play/pause on the Now Playing card (rate alone is not
    /// honored). No duration is reported, so no progress bar is shown.
    private var chapterStartDate: Date?

    // MARK: - Initialization

    init(
        synthesizer: SpeechSynthesizer,
        settingsRepository: TTSSettingsRepository,
        voiceProvider: VoiceProvider,
        audioSessionConfigurator: AudioSessionConfigurable = SystemAudioSessionConfigurator(),
        remoteCommandConfigurator: RemoteCommandConfigurable = SystemRemoteCommandConfigurator(),
        interruptionObservable: InterruptionObservable = NotificationCenterInterruptionObserver(),
        recordingStateProvider: RecordingStateProvider = AudioServiceRecordingStateProvider(),
        nowPlayingInfoCenter: NowPlayingInfoCenterProtocol? = nil
    ) {
        self.synthesizer = synthesizer
        self.settingsRepository = settingsRepository
        self.voiceProvider = voiceProvider
        self.audioSessionConfigurator = audioSessionConfigurator
        self.remoteCommandConfigurator = remoteCommandConfigurator
        self.interruptionObservable = interruptionObservable
        self.recordingStateProvider = recordingStateProvider
        self.nowPlayingInfoCenter = nowPlayingInfoCenter ?? SystemNowPlayingInfoCenter()
        self.settings = settingsRepository.loadSettings()

        super.init()

        self.synthesizer.delegate = self
        setupRemoteCommandCenter()
        setupInterruptionHandling()
    }

    // MARK: - Public Methods

    func startReading(verses: [BibleVerse], language: String, startIndex: Int = 0) {
        guard !verses.isEmpty else {
            Logger.tts.warning("Cannot start reading: verses list is empty")
            return
        }

        guard !recordingStateProvider.isRecording else {
            Logger.tts.warning("Cannot start reading while recording is in progress")
            return
        }

        // 1. 즉시 상태 업데이트 (UI 애니메이션이 블로킹되지 않도록)
        self.verses = verses
        self.currentVerseIndex = min(startIndex, verses.count - 1)
        self.bookName = verses.first?.bookName ?? ""
        self.bookCode = verses.first?.bookCode ?? ""
        self.chapterNum = verses.first?.chapter ?? 0
        self.currentLanguage = language
        playbackState = .playing
        isPauseRequested = false
        chapterStartDate = Date()

        Logger.tts.info("Started reading \(self.bookName) \(self.chapterNum) from verse \(self.currentVerseIndex + 1) in \(language)")

        // 2. 무거운 작업은 다음 런루프에서 실행 (UI 블로킹 방지)
        operationGeneration += 1
        let currentGen = operationGeneration
        Task { @MainActor in
            guard operationGeneration == currentGen else { return }
            // Reset all state before starting
            restartTask?.cancel()
            restartTask = nil
            nextChapterTask?.cancel()
            nextChapterTask = nil
            isRestarting = false
            isSynthesizerBusy = false
            synthesizer.stop()
            synthesizer.recreate()

            setupAudioSession()
            speakCurrentVerse()
        }
    }

    func switchChapter(verses: [BibleVerse], language: String, forcePlay: Bool = false, startIndex: Int = 0) {
        guard !verses.isEmpty else {
            Logger.tts.warning("Cannot switch chapter: verses list is empty")
            return
        }
        guard !isSynthesizerBusy else { return }

        let wasPlaying = playbackState == .playing || forcePlay

        // Stop current speech without changing playbackState
        restartTask?.cancel()
        restartTask = nil
        nextChapterTask?.cancel()
        nextChapterTask = nil

        isSynthesizerBusy = true
        isRestarting = true
        synthesizer.stop()
        synthesizer.recreate()

        // Update chapter data
        self.verses = verses
        self.currentVerseIndex = min(startIndex, verses.count - 1)
        self.bookName = verses.first?.bookName ?? ""
        self.bookCode = verses.first?.bookCode ?? ""
        self.chapterNum = verses.first?.chapter ?? 0
        self.currentLanguage = language
        chapterStartDate = Date()

        isRestarting = false
        isSynthesizerBusy = false

        // Continue with same state
        if wasPlaying {
            playbackState = .playing
            speakCurrentVerse()
        } else {
            playbackState = .paused
            syncNowPlayingState()
        }

        Logger.tts.info("Switched to \(self.bookName) \(self.chapterNum):\(self.currentVerseIndex + 1), wasPlaying: \(wasPlaying)")
    }

    func pause() {
        restartTask?.cancel()
        restartTask = nil

        if isSynthesizerBusy || isRestarting {
            isRestarting = true
            synthesizer.stop()
            synthesizer.recreate()
            isRestarting = false
            isSynthesizerBusy = false
            isPauseRequested = false
        } else {
            synthesizer.pause()
            isPauseRequested = true
        }
        playbackState = .paused
        syncNowPlayingState()
        Logger.tts.debug("Paused at verse \(self.currentVerseIndex + 1)")
    }

    func resume() {
        guard !isSynthesizerBusy else { return }

        nextChapterTask?.cancel()
        nextChapterTask = nil

        if synthesizer.isPaused {
            // 정상 케이스: 일시정지 완료 → 이어서 재생
            isPauseRequested = false
            synthesizer.resume()
        } else if isPauseRequested || synthesizer.isSpeaking {
            // 빠른 토글: 일시정지 요청했지만 아직 완료 안 됨 → 정리 후 절 재시작
            isPauseRequested = false
            isRestarting = true
            synthesizer.stop()
            synthesizer.recreate()
            isRestarting = false
            speakCurrentVerse()
        } else {
            // 정지 상태에서 재개 → 절 재시작
            isPauseRequested = false
            speakCurrentVerse()
        }
        playbackState = .playing
        syncNowPlayingState()
        Logger.tts.debug("Resumed at verse \(self.currentVerseIndex + 1)")
    }

    func stop() {
        // 1. 즉시 상태 업데이트 (UI 애니메이션이 블로킹되지 않도록)
        playbackState = .idle
        isPauseRequested = false
        currentVerseIndex = 0
        verses = []
        chapterStartDate = nil

        Logger.tts.info("Stopped playback")

        // 2. 무거운 작업은 다음 런루프에서 실행 (UI 블로킹 방지)
        operationGeneration += 1
        let currentGen = operationGeneration
        Task { @MainActor in
            guard operationGeneration == currentGen else { return }
            restartTask?.cancel()
            restartTask = nil
            nextChapterTask?.cancel()
            nextChapterTask = nil
            isRestarting = false
            isSynthesizerBusy = false
            synthesizer.stop()
            synthesizer.recreate()
            syncNowPlayingState(withInfo: false)
            clearNowPlayingInfo()
            deactivateAudioSession()
        }
    }

    func skipToNext() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil

        if currentVerseIndex < verses.count - 1 {
            currentVerseIndex += 1
            if playbackState == .playing {
                isSynthesizerBusy = true
                isRestarting = true
                synthesizer.stop()
                synthesizer.recreate()

                isRestarting = false
                isSynthesizerBusy = false
                speakCurrentVerse()
            }
        } else {
            stop()
        }
    }

    func skipToPrevious() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil

        if currentVerseIndex > 0 {
            currentVerseIndex -= 1
        }
        if playbackState == .playing {
            isSynthesizerBusy = true
            isRestarting = true
            synthesizer.stop()
            synthesizer.recreate()

            isRestarting = false
            isSynthesizerBusy = false
            speakCurrentVerse()
        }
    }

    func skipToFirst() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil

        currentVerseIndex = 0

        if playbackState == .playing {
            isSynthesizerBusy = true
            isRestarting = true
            synthesizer.stop()
            synthesizer.recreate()

            isRestarting = false
            isSynthesizerBusy = false
            speakCurrentVerse()
        }
    }

    func skipToVerse(at index: Int) {
        guard index >= 0, index < verses.count else { return }
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil

        currentVerseIndex = index

        guard playbackState == .playing else { return }

        isSynthesizerBusy = true
        isRestarting = true
        synthesizer.stop()
        synthesizer.recreate()

        isRestarting = false
        isSynthesizerBusy = false
        speakCurrentVerse()
    }

    func setVoice(_ voice: TTSVoiceConfig?, for language: String) {
        if language == "Korean" {
            settings.koreanVoiceIdentifier = voice?.identifier
        } else {
            settings.englishVoiceIdentifier = voice?.identifier
        }
        settingsRepository.saveSettings(settings)

        Logger.tts.debug("Voice changed to: \(voice?.name ?? "System Default") for \(language)")

        // 현재 재생 중이고, 변경된 언어가 현재 언어와 같으면 현재 절 다시 재생
        if playbackState == .playing && language == currentLanguage {
            restartCurrentVerse()
        }
    }

    func setSpeechRate(_ rate: Float) {
        guard rate != settings.speechRate else { return }

        settings.speechRate = rate
        settingsRepository.saveSettings(settings)

        Logger.tts.debug("Speech rate changed to: \(rate)")

        // 현재 재생 중이고 재시작 중이 아닐 때만 현재 절 다시 재생
        if playbackState == .playing && !isRestarting {
            restartCurrentVerse()
            
        }
    }

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused:
            resume()
        case .idle:
            break
        }
    }

    func refreshVoices() {
        voiceProvider.refreshVoices()
        synthesizer.clearVoiceCache()
    }

    // MARK: - Private Methods

    private func updateSpeechRate(_ rate: Float) {
        setSpeechRate(rate)
    }

    private func restartCurrentVerse() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil

        isSynthesizerBusy = true
        isRestarting = true
        synthesizer.stop()
        synthesizer.recreate()

        isSynthesizerBusy = false

        if playbackState == .playing {
            isRestarting = false
            speakCurrentVerse()
            Logger.tts.debug("Restarted current verse directly")
        }
    }

    private func speakCurrentVerse() {
        while currentVerseIndex < verses.count {
            let verse = verses[currentVerseIndex]
            if let text = verse.verseText, !text.isEmpty {
                synthesizer.speak(text: text, voice: currentVoice, rate: settings.speechRate)
                updateNowPlayingInfo()
                return
            }
            Logger.tts.warning("Skipping verse \(verse.verse): no text")
            currentVerseIndex += 1
        }
        stop()
    }

    // MARK: - Audio Interruption Handling

    private func setupInterruptionHandling() {
        guard !PlatformHelper.isRunningOnMac else { return }
        interruptionObserverToken = interruptionObservable.addInterruptionObserver { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            if playbackState == .playing {
                pause()
                Logger.tts.info("Playback paused due to audio interruption")
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && playbackState == .paused {
                    resume()
                    Logger.tts.info("Playback resumed after audio interruption")
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        // AVAudioSession is iOS-only; skip on macOS to avoid blocking TTS
        guard !PlatformHelper.isRunningOnMac else {
            Logger.tts.debug("Running on macOS - skipping audio session setup")
            return
        }

        do {
            try audioSessionConfigurator.activatePlaybackSession()
            Logger.tts.debug("Audio session activated for TTS playback")
        } catch {
            Logger.tts.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        // AVAudioSession is iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else {
            Logger.tts.debug("Running on macOS - skipping audio session deactivation")
            return
        }

        do {
            try audioSessionConfigurator.deactivatePlaybackSession()
            Logger.tts.debug("Audio session deactivated")
        } catch {
            Logger.tts.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Remote Command Center

    private func setupRemoteCommandCenter() {
        // MPRemoteCommandCenter is iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else {
            Logger.tts.debug("Running on macOS - skipping remote command center setup")
            return
        }

        remoteCommandConfigurator.configureCommands(
            onPlay: { [weak self] in
                Task { @MainActor in
                    self?.resume()
                }
            },
            onPause: { [weak self] in
                Task { @MainActor in
                    self?.pause()
                }
            },
            onTogglePlayPause: { [weak self] in
                Task { @MainActor in
                    self?.togglePlayPause()
                }
            },
            onNextTrack: { [weak self] in
                Task { @MainActor in
                    self?.skipToNext()
                }
            },
            onPreviousTrack: { [weak self] in
                Task { @MainActor in
                    self?.skipToPrevious()
                }
            }
        )

        Logger.tts.debug("Remote command center configured")
    }

    // MARK: - Now Playing Info

    /// 중앙 재생 상태 동기화 헬퍼 — 모든 재생 상태 전이가 이 경로를 통해
    /// 시스템 Now Playing 상태와 앱 상태를 동기화한다.
    /// - `withInfo: true`인 경우 메타데이터와 재생 상태를 함께 갱신한다.
    /// - `withInfo: false`인 경우 재생 상태만 동기화한다 (절 데이터가 없는 전이에서 사용).
    private func syncNowPlayingState(withInfo: Bool = true) {
        guard !PlatformHelper.isRunningOnMac else { return }

        if withInfo, !verses.isEmpty, currentVerseIndex < verses.count {
            updateNowPlayingInfo()
        } else {
            nowPlayingInfoCenter.setPlaybackState(nowPlayingPlaybackState)
        }
    }

    /// Seconds since the current chapter started playing. Only anchors the card's
    /// play/pause state; the precise value is irrelevant (no progress bar is shown).
    private var currentElapsed: TimeInterval {
        guard let chapterStartDate else { return 0 }
        return Date().timeIntervalSince(chapterStartDate)
    }

    private func updateNowPlayingInfo() {
        // MPNowPlayingInfoCenter is iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else { return }

        guard !verses.isEmpty, currentVerseIndex < verses.count else { return }

        var nowPlayingInfo = [String: Any]()

        // Chapter-level "track": the whole chapter is one item, not each verse.
        nowPlayingInfo[MPMediaItemPropertyTitle] = chapterTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = "HagaBible"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = bookName

        // Play/pause icon only (no progress bar). iOS needs BOTH the playback rate
        // and an elapsed time to reflect pause reliably — rate alone is ignored when
        // pausing from inside the app. Duration is omitted so no scrubber/progress
        // bar is shown; the elapsed value only anchors the play/pause state.
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentElapsed

        nowPlayingInfoCenter.updateNowPlayingInfo(nowPlayingInfo)
        nowPlayingInfoCenter.setPlaybackState(nowPlayingPlaybackState)
        Logger.tts.info("Now Playing info set: title=\(nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "?"), rate=\(nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? -1), elapsed=\(self.currentElapsed)")
    }

    private func clearNowPlayingInfo() {
        // MPNowPlayingInfoCenter is iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else { return }

        nowPlayingInfoCenter.clearNowPlayingInfo()
    }

    private var nowPlayingPlaybackState: MPNowPlayingPlaybackState {
        switch playbackState {
        case .idle:
            .stopped
        case .playing:
            .playing
        case .paused:
            .paused
        }
    }
}

// MARK: - SpeechSynthesizerDelegate

extension TTSPlaybackManager: SpeechSynthesizerDelegate {
    func speechDidStart() {
        // 오디오가 실제로 출력되기 시작한 시점에 nowPlayingInfo를 다시 설정해야
        // iOS가 이 앱을 "Now Playing 앱"으로 등록한다. AVAudioEngine 렌더링은
        // 비동기로 시작되므로 speakCurrentVerse 시점(아래 updateNowPlayingInfo)에는
        // 아직 오디오가 나오지 않아 MediaRemote가 등록을 건너뛴다.
        guard playbackState == .playing else { return }
        updateNowPlayingInfo()
    }

    func speechDidResetEngine() {
        // 출력 라우트/포맷 변경(예: 블루투스 HFP→A2DP 전환)으로 오디오 엔진이 재시작되며
        // 진행 중이던 발화의 스케줄 버퍼가 유실됐다. 재생 중이라면 현재 절을 처음부터 다시
        // 읽어 복구한다(= 사용자가 수동으로 하던 정지→재생 자동화).
        guard playbackState == .playing else { return }
        guard !isRestarting, !isSynthesizerBusy else { return }
        Logger.tts.info("Re-speaking current verse after audio engine reset")
        speakCurrentVerse()
    }

    func speechDidFinish() {
        guard playbackState != .idle else {
            Logger.tts.debug("didFinish skipped - already idle")
            return
        }

        if isRestarting {
            Logger.tts.debug("didFinish skipped - restarting")
            return
        }

        // Move to next verse when current one finishes
        if currentVerseIndex < verses.count - 1 {
            currentVerseIndex += 1
            speakCurrentVerse()
        } else {
            // Finished all verses - wait 3 seconds then trigger next chapter
            Logger.tts.info("Finished reading all verses, waiting 3 seconds for next chapter")
            playbackState = .paused
            syncNowPlayingState()

            nextChapterTask?.cancel()
            nextChapterTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }

                guard let self = self else { return }
                guard self.playbackState == .paused else { return }

                if let onChapterFinished = self.onChapterFinished {
                    onChapterFinished()
                } else {
                    self.stop()
                }
            }
        }
    }

    func speechDidPause() {
        // playbackState는 pause()에서 이미 즉시 설정됨.
        // 비동기 콜백에서 다시 설정하면 빠른 토글 시 상태 충돌 발생하므로 변경하지 않음.
    }

    func speechDidContinue() {
        // playbackState는 resume()에서 이미 즉시 설정됨.
        // 비동기 콜백에서 다시 설정하면 빠른 토글 시 상태 충돌 발생하므로 변경하지 않음.
    }

    func speechDidCancel() {
        if isRestarting {
            Logger.tts.debug("didCancel skipped - restarting")
            return
        }
        Logger.tts.debug("Speech cancelled")
    }
}
