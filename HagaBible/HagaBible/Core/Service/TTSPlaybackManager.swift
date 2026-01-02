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

    // MARK: - Internal State

    private var settings: TTSSettings
    private var isRestarting = false
    private var restartTask: Task<Void, Never>?
    private var nextChapterTask: Task<Void, Never>?
    private var skipRequestId: UUID?
    private var isSynthesizerBusy = false
    private let synthesizerLock = NSLock()

    // MARK: - Initialization

    init(
        synthesizer: SpeechSynthesizer,
        settingsRepository: TTSSettingsRepository,
        voiceProvider: VoiceProvider
    ) {
        self.synthesizer = synthesizer
        self.settingsRepository = settingsRepository
        self.voiceProvider = voiceProvider
        self.settings = settingsRepository.loadSettings()

        super.init()

        self.synthesizer.delegate = self
        setupRemoteCommandCenter()
    }

    // MARK: - Public Methods

    func startReading(verses: [BibleVerse], language: String, startIndex: Int = 0) {
        guard !verses.isEmpty else {
            Logger.tts.warning("Cannot start reading: verses list is empty")
            return
        }

        // Reset all state before starting
        restartTask?.cancel()
        restartTask = nil
        nextChapterTask?.cancel()
        nextChapterTask = nil
        skipRequestId = nil
        isRestarting = false
        isSynthesizerBusy = false
        synthesizer.stop()
        synthesizer.recreate()

        self.verses = verses
        self.currentVerseIndex = min(startIndex, verses.count - 1)
        self.bookName = verses.first?.bookName ?? ""
        self.chapterNum = verses.first?.chapter ?? 0
        self.currentLanguage = language

        setupAudioSession()
        playbackState = .playing
        speakCurrentVerse()

        Logger.tts.info("Started reading \(self.bookName) \(self.chapterNum) from verse \(self.currentVerseIndex + 1) in \(language)")
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
        skipRequestId = nil

        isSynthesizerBusy = true
        isRestarting = true
        synthesizer.stop()
        synthesizer.recreate()

        // Update chapter data
        self.verses = verses
        self.currentVerseIndex = min(startIndex, verses.count - 1)
        self.bookName = verses.first?.bookName ?? ""
        self.chapterNum = verses.first?.chapter ?? 0
        self.currentLanguage = language

        isRestarting = false
        isSynthesizerBusy = false

        // Continue with same state
        if wasPlaying {
            playbackState = .playing
            speakCurrentVerse()
        } else {
            playbackState = .paused
            updateNowPlayingInfo()
        }

        Logger.tts.info("Switched to \(self.bookName) \(self.chapterNum):\(self.currentVerseIndex + 1), wasPlaying: \(wasPlaying)")
    }

    func pause() {
        let hadPendingOperation = isSynthesizerBusy || isRestarting
        restartTask?.cancel()
        restartTask = nil
        skipRequestId = nil
        isSynthesizerBusy = false
        isRestarting = false

        if hadPendingOperation {
            synthesizer.stop()
            synthesizer.recreate()
        } else {
            synthesizer.pause()
        }
        playbackState = .paused
        updateNowPlayingInfo()
        Logger.tts.debug("Paused at verse \(self.currentVerseIndex + 1)")
    }

    func resume() {
        guard !isSynthesizerBusy else { return }

        if synthesizer.isPaused {
            synthesizer.resume()
        } else {
            speakCurrentVerse()
        }
        playbackState = .playing
        updateNowPlayingInfo()
        Logger.tts.debug("Resumed at verse \(self.currentVerseIndex + 1)")
    }

    func stop() {
        restartTask?.cancel()
        restartTask = nil
        nextChapterTask?.cancel()
        nextChapterTask = nil
        skipRequestId = nil
        isRestarting = false
        isSynthesizerBusy = false
        synthesizer.stop()
        synthesizer.recreate()
        playbackState = .idle
        currentVerseIndex = 0
        verses = []
        clearNowPlayingInfo()
        deactivateAudioSession()
        Logger.tts.info("Stopped playback")
    }

    func skipToNext() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil
        skipRequestId = nil

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
        skipRequestId = nil

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
        skipRequestId = nil

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
        skipRequestId = nil

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

    // MARK: - Private Methods

    private func updateSpeechRate(_ rate: Float) {
        setSpeechRate(rate)
    }

    private func restartCurrentVerse() {
        guard !isSynthesizerBusy else { return }

        restartTask?.cancel()
        restartTask = nil
        skipRequestId = nil

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
        guard currentVerseIndex < verses.count else {
            stop()
            return
        }

        let verse = verses[currentVerseIndex]
        guard let text = verse.verseText, !text.isEmpty else {
            Logger.tts.warning("Skipping verse \(verse.verse): no text")
            skipToNext()
            return
        }

        synthesizer.speak(text: text, voice: currentVoice, rate: settings.speechRate)
        updateNowPlayingInfo()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            Logger.tts.debug("Audio session activated for TTS playback")
        } catch {
            Logger.tts.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            Logger.tts.debug("Audio session deactivated")
        } catch {
            Logger.tts.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Remote Command Center

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToPrevious()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        Logger.tts.debug("Remote command center configured")
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        guard !verses.isEmpty, currentVerseIndex < verses.count else { return }

        let verse = verses[currentVerseIndex]
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(bookName) \(chapterNum):\(verse.verse)"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "HagaBible"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = bookName
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = currentVerseIndex + 1
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = verses.count

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

// MARK: - SpeechSynthesizerDelegate

extension TTSPlaybackManager: SpeechSynthesizerDelegate {
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
            updateNowPlayingInfo()

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
        playbackState = .paused
        updateNowPlayingInfo()
    }

    func speechDidContinue() {
        playbackState = .playing
        updateNowPlayingInfo()
    }

    func speechDidCancel() {
        if isRestarting {
            Logger.tts.debug("didCancel skipped - restarting")
            return
        }
        Logger.tts.debug("Speech cancelled")
    }
}
