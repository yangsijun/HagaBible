//
//  TTSService.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import AVFoundation
import MediaPlayer
import OSLog

enum TTSPlaybackState: Equatable {
    case idle
    case playing
    case paused
}

@MainActor
@Observable
class TTSService: NSObject {
    // MARK: - Public Properties
    var playbackState: TTSPlaybackState = .idle
    var currentVerseIndex: Int = 0
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    var selectedKoreanVoice: AVSpeechSynthesisVoice?
    var selectedEnglishVoice: AVSpeechSynthesisVoice?
    var koreanVoices: [AVSpeechSynthesisVoice] = []
    var englishVoices: [AVSpeechSynthesisVoice] = []

    // MARK: - Read-only Properties
    private(set) var verses: [BibleVerse] = []
    private(set) var bookName: String = ""
    private(set) var chapterNum: Int = 0
    private(set) var currentLanguage: String = "Korean"
    var totalVerses: Int { verses.count }

    var currentVoice: AVSpeechSynthesisVoice? {
        if currentLanguage == "Korean" {
            return selectedKoreanVoice ?? AVSpeechSynthesisVoice(language: "ko")
        } else {
            return selectedEnglishVoice ?? AVSpeechSynthesisVoice(language: "en")
        }
    }

    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var isRestarting = false
    private var restartTask: Task<Void, Never>?

    // MARK: - UserDefaults Keys
    private enum UserDefaultsKeys {
        static let selectedKoreanVoiceIdentifier = "tts_selected_korean_voice_identifier"
        static let selectedEnglishVoiceIdentifier = "tts_selected_english_voice_identifier"
        static let speechRate = "tts_speech_rate"
    }

    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
        loadUserPreferences()
        setupRemoteCommandCenter()
    }

    // MARK: - Public Methods
    func startReading(verses: [BibleVerse], language: String, startIndex: Int = 0) {
        guard !verses.isEmpty else {
            Logger.tts.warning("Cannot start reading: verses list is empty")
            return
        }

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

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        playbackState = .paused
        updateNowPlayingInfo()
        Logger.tts.debug("Paused at verse \(self.currentVerseIndex + 1)")
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
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
        isRestarting = false
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
        currentVerseIndex = 0
        verses = []
        clearNowPlayingInfo()
        deactivateAudioSession()
        Logger.tts.info("Stopped playback")
    }

    func skipToNext() {
        restartTask?.cancel()
        isRestarting = false
        synthesizer.stopSpeaking(at: .immediate)
        if currentVerseIndex < verses.count - 1 {
            currentVerseIndex += 1
            if playbackState == .playing {
                speakCurrentVerse()
            }
        } else {
            stop()
        }
    }

    func skipToPrevious() {
        restartTask?.cancel()
        isRestarting = false
        synthesizer.stopSpeaking(at: .immediate)
        if currentVerseIndex > 0 {
            currentVerseIndex -= 1
        }
        if playbackState == .playing {
            speakCurrentVerse()
        }
    }

    func skipToVerse(at index: Int) {
        guard index >= 0, index < verses.count else { return }
        restartTask?.cancel()
        isRestarting = false
        synthesizer.stopSpeaking(at: .immediate)
        currentVerseIndex = index
        if playbackState == .playing {
            speakCurrentVerse()
        }
    }

    func setVoice(_ voice: AVSpeechSynthesisVoice?, for language: String) {
        if language == "Korean" {
            selectedKoreanVoice = voice
            if let voice = voice {
                UserDefaults.standard.set(voice.identifier, forKey: UserDefaultsKeys.selectedKoreanVoiceIdentifier)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedKoreanVoiceIdentifier)
            }
        } else {
            selectedEnglishVoice = voice
            if let voice = voice {
                UserDefaults.standard.set(voice.identifier, forKey: UserDefaultsKeys.selectedEnglishVoiceIdentifier)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedEnglishVoiceIdentifier)
            }
        }
        Logger.tts.debug("Voice changed to: \(voice?.name ?? "System Default") for \(language)")

        // 현재 재생 중이고, 변경된 언어가 현재 언어와 같으면 현재 절 다시 재생
        if playbackState == .playing && language == currentLanguage {
            restartCurrentVerse()
        }
    }

    func setSpeechRate(_ rate: Float) {
        // 값이 같으면 무시
        guard rate != speechRate else { return }

        speechRate = rate
        UserDefaults.standard.set(rate, forKey: UserDefaultsKeys.speechRate)
        Logger.tts.debug("Speech rate changed to: \(rate)")

        // 현재 재생 중이고 재시작 중이 아닐 때만 현재 절 다시 재생
        if playbackState == .playing && !isRestarting {
            restartCurrentVerse()
        }
    }

    private func restartCurrentVerse() {
        // Cancel any existing restart task
        restartTask?.cancel()

        isRestarting = true
        synthesizer.stopSpeaking(at: .immediate)

        // Directly restart after a brief delay to ensure clean state
        restartTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            if self.playbackState == .playing {
                self.isRestarting = false
                self.speakCurrentVerse()
                Logger.tts.debug("Restarted current verse directly")
            }
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

    private func loadAvailableVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Korean: ko-KR only
        koreanVoices = filterVoicesByQuality(
            allVoices.filter { $0.language == "ko-KR" }
        )

        // English: en-US and en-GB
        englishVoices = filterVoicesByQuality(
            allVoices.filter { $0.language == "en-US" || $0.language == "en-GB" }
        )

        Logger.tts.info("Loaded \(self.koreanVoices.count) Korean voices, \(self.englishVoices.count) English voices")
    }

    /// Premium/Enhanced 음성은 모두 포함, 3개 미만이면 Default로 채워서 최대 3개
    private func filterVoicesByQuality(_ voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        let premiumEnhanced = voices.filter { $0.quality == .premium || $0.quality == .enhanced }
        let defaultVoices = voices.filter { $0.quality == .default }

        if premiumEnhanced.count >= 3 {
            // Premium/Enhanced가 3개 이상이면 Default 제외
            return premiumEnhanced.sorted { voiceQualityOrder($0) < voiceQualityOrder($1) }
        } else {
            // 3개 미만이면 Default로 채워서 총 3개까지
            let needed = 3 - premiumEnhanced.count
            let filledDefaults = Array(defaultVoices.prefix(needed))
            return (premiumEnhanced + filledDefaults).sorted { voiceQualityOrder($0) < voiceQualityOrder($1) }
        }
    }

    private func voiceQualityOrder(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium:
            return 0
        case .enhanced:
            return 1
        default:
            return 2
        }
    }

    private func loadUserPreferences() {
        // Load saved Korean voice (nil = System Default)
        if let savedIdentifier = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedKoreanVoiceIdentifier) {
            selectedKoreanVoice = koreanVoices.first(where: { $0.identifier == savedIdentifier })
        } else {
            selectedKoreanVoice = nil  // System Default
        }

        // Load saved English voice (nil = System Default)
        if let savedIdentifier = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedEnglishVoiceIdentifier) {
            selectedEnglishVoice = englishVoices.first(where: { $0.identifier == savedIdentifier })
        } else {
            selectedEnglishVoice = nil  // System Default
        }

        // Load saved speech rate
        let savedRate = UserDefaults.standard.float(forKey: UserDefaultsKeys.speechRate)
        if savedRate > 0 {
            speechRate = savedRate
        }

        Logger.tts.debug("Loaded user preferences - Korean: \(self.selectedKoreanVoice?.name ?? "System Default"), English: \(self.selectedEnglishVoice?.name ?? "System Default"), rate: \(self.speechRate)")
    }

    private func speakCurrentVerse() {
        guard currentVerseIndex < verses.count else {
            stop()
            return
        }

        let verse = verses[currentVerseIndex]
        guard let text = verse.verseText, !text.isEmpty else {
            // Skip verses with no text
            Logger.tts.warning("Skipping verse \(verse.verse): no text")
            skipToNext()
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        synthesizer.speak(utterance)
        updateNowPlayingInfo()
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        // Next Track
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToNext()
            }
            return .success
        }

        // Previous Track
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToPrevious()
            }
            return .success
        }

        // Disable unsupported commands
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        Logger.tts.debug("Remote command center configured")
    }

    private func updateNowPlayingInfo() {
        guard !verses.isEmpty, currentVerseIndex < verses.count else { return }

        let verse = verses[currentVerseIndex]
        var nowPlayingInfo = [String: Any]()

        // Title: "Genesis 1:1"
        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(bookName) \(chapterNum):\(verse.verse)"

        // Artist: App name
        nowPlayingInfo[MPMediaItemPropertyArtist] = "HagaBible"

        // Album: Book name
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = bookName

        // Playback info
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackState == .playing ? 1.0 : 0.0

        // Track numbers (verse / total verses)
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = currentVerseIndex + 1
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = verses.count

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // If we're restarting current verse, skip auto-advance (Task in restartCurrentVerse will handle it)
            if self.isRestarting {
                Logger.tts.debug("didFinish skipped - restarting")
                return
            }

            // Move to next verse when current one finishes
            if self.currentVerseIndex < self.verses.count - 1 {
                self.currentVerseIndex += 1
                self.speakCurrentVerse()
            } else {
                // Finished all verses
                self.stop()
                Logger.tts.info("Finished reading all verses")
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackState = .paused
            self.updateNowPlayingInfo()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackState = .playing
            self.updateNowPlayingInfo()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Skip if restarting (Task in restartCurrentVerse will handle it)
            if self.isRestarting {
                Logger.tts.debug("didCancel skipped - restarting")
                return
            }
            Logger.tts.debug("Speech cancelled")
        }
    }
}
