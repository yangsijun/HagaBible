//
//  TTSViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 1/3/26.
//

import Foundation
import AVFoundation

@MainActor
@Observable
class TTSViewModel {
    // MARK: - Dependencies

    private let ttsManager: TTSPlaybackManager
    /// The reader the current session reads from: chapter changes from the player land in
    /// its window. Set when a session starts; with several windows open, only that window
    /// highlights the spoken verse and follows the player. Weak: a closed window's reader
    /// must not be kept alive by a stale session.
    private(set) weak var reader: BibleReaderViewModel?

    // MARK: - Forwarded Properties

    var playbackState: TTSPlaybackState {
        ttsManager.playbackState
    }

    /// Whether a reading session exists (playing or paused). RootView's bottom accessory
    /// observes this — NOT `playbackState` — so a play↔pause toggle doesn't invalidate the
    /// parent and re-host the accessory (which would break the mini player's animations).
    var isSessionActive: Bool {
        ttsManager.isSessionActive
    }

    var currentVerseIndex: Int {
        ttsManager.currentVerseIndex
    }

    var verses: [BibleVerse] {
        ttsManager.verses
    }

    var bookName: String {
        ttsManager.bookName
    }

    var chapterNum: Int {
        ttsManager.chapterNum
    }

    var chapterTitle: String {
        ttsManager.chapterTitle
    }

    var totalVerses: Int {
        ttsManager.totalVerses
    }

    var speechRate: Float {
        get { ttsManager.speechRate }
        set { ttsManager.setSpeechRate(newValue) }
    }

    var koreanVoices: [TTSVoiceConfig] {
        ttsManager.koreanVoices
    }

    var englishVoices: [TTSVoiceConfig] {
        ttsManager.englishVoices
    }

    var selectedKoreanVoice: TTSVoiceConfig? {
        ttsManager.selectedKoreanVoice
    }

    var selectedEnglishVoice: TTSVoiceConfig? {
        ttsManager.selectedEnglishVoice
    }

    var onChapterFinished: (() -> Void)? {
        get { ttsManager.onChapterFinished }
        set { ttsManager.onChapterFinished = newValue }
    }

    // MARK: - Initialization

    init(ttsManager: TTSPlaybackManager) {
        self.ttsManager = ttsManager
    }

    /// True while a session is reading from this reader (this window). Other windows show
    /// the mini player too, since the audio is shared, but must not highlight or follow.
    func isReading(_ reader: BibleReaderViewModel) -> Bool {
        playbackState != .idle && self.reader === reader
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        ttsManager.togglePlayPause()
    }

    func pause() {
        ttsManager.pause()
    }

    func resume() {
        ttsManager.resume()
    }

    func stop() {
        ttsManager.stop()
    }

    func skipToVerse(at index: Int) {
        ttsManager.skipToVerse(at: index)
    }

    func skipToNext() {
        ttsManager.skipToNext()
    }

    func skipToPrevious() {
        ttsManager.skipToPrevious()
    }

    // MARK: - Chapter Navigation

    func goToNextChapter(forcePlay: Bool = false) {
        guard let reader else { return }
        Task {
            await reader.goToNextChapterAsync()
            reader.bibleNavigationUpdateTrigger.toggle()
            switchChapter(from: reader, forcePlay: forcePlay)
        }
    }

    func goToPreviousChapter() {
        // 1절이 아니면 현재 장의 1절로 이동
        if ttsManager.currentVerseIndex > 0 {
            ttsManager.skipToFirst()
            return
        }

        // 1절이면 이전 장으로 이동
        guard let reader else { return }
        Task {
            await reader.goToPreviousChapterAsync()
            reader.bibleNavigationUpdateTrigger.toggle()
            switchChapter(from: reader)
        }
    }

    /// Continues the session in the reader's current chapter (after it navigated).
    func switchChapter(from reader: BibleReaderViewModel, forcePlay: Bool = false, startIndex: Int = 0) {
        self.reader = reader
        ttsManager.switchChapter(
            verses: reader.bibleVerseList,
            language: reader.bibleVersion?.language ?? "Korean",
            forcePlay: forcePlay,
            startIndex: startIndex
        )
    }

    // MARK: - Settings

    func setVoice(_ voice: TTSVoiceConfig?, for language: String) {
        ttsManager.setVoice(voice, for: language)
    }

    func setSpeechRate(_ rate: Float) {
        ttsManager.setSpeechRate(rate)
    }

    // MARK: - Reading Control

    /// Starts a session reading the reader's current chapter; that reader's window owns the
    /// session from here (see `reader`).
    func startReading(from reader: BibleReaderViewModel, startIndex: Int = 0) {
        self.reader = reader
        ttsManager.startReading(
            verses: reader.bibleVerseList,
            language: reader.bibleVersion?.language ?? "Korean",
            startIndex: startIndex
        )
    }

    func refreshVoices() {
        ttsManager.refreshVoices()
    }

    /// Forwarded to the manager on app foreground so a session that iOS silently
    /// deactivated while suspended (mini player visible, "playing", but no audio)
    /// recovers instead of sitting stalled at the current verse.
    func handleForegroundTransition() {
        ttsManager.handleForegroundTransition()
    }
}
