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
    private let bibleReaderViewModel: BibleReaderViewModel

    // MARK: - Forwarded Properties

    var playbackState: TTSPlaybackState {
        ttsManager.playbackState
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

    init(ttsManager: TTSPlaybackManager, bibleReaderViewModel: BibleReaderViewModel) {
        self.ttsManager = ttsManager
        self.bibleReaderViewModel = bibleReaderViewModel
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
        Task {
            await bibleReaderViewModel.goToNextChapterAsync()
            bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
            let language = bibleReaderViewModel.bibleVersion?.language ?? "Korean"
            ttsManager.switchChapter(verses: bibleReaderViewModel.bibleVerseList, language: language, forcePlay: forcePlay)
        }
    }

    func goToPreviousChapter() {
        // 1절이 아니면 현재 장의 1절로 이동
        if ttsManager.currentVerseIndex > 0 {
            ttsManager.skipToFirst()
            return
        }

        // 1절이면 이전 장으로 이동
        Task {
            await bibleReaderViewModel.goToPreviousChapterAsync()
            bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()
            let language = bibleReaderViewModel.bibleVersion?.language ?? "Korean"
            ttsManager.switchChapter(verses: bibleReaderViewModel.bibleVerseList, language: language)
        }
    }

    func switchChapter(verses: [BibleVerse], language: String, forcePlay: Bool = false, startIndex: Int = 0) {
        ttsManager.switchChapter(verses: verses, language: language, forcePlay: forcePlay, startIndex: startIndex)
    }

    // MARK: - Settings

    func setVoice(_ voice: TTSVoiceConfig?, for language: String) {
        ttsManager.setVoice(voice, for: language)
    }

    func setSpeechRate(_ rate: Float) {
        ttsManager.setSpeechRate(rate)
    }

    // MARK: - Reading Control

    func startReading(verses: [BibleVerse], language: String, startIndex: Int = 0) {
        ttsManager.startReading(verses: verses, language: language, startIndex: startIndex)
    }

    func refreshVoices() {
        ttsManager.refreshVoices()
    }
}
