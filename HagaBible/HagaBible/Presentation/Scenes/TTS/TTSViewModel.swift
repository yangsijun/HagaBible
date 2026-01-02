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

    func goToNextChapter() {
        bibleReaderViewModel.goToNextChapter()
        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let language = bibleReaderViewModel.bibleVersion?.language ?? "Korean"
            ttsManager.switchChapter(verses: bibleReaderViewModel.bibleVerseList, language: language)
        }
    }

    func goToPreviousChapter() {
        bibleReaderViewModel.goToPreviousChapter()
        bibleReaderViewModel.bibleNavigationUpdateTrigger.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let language = bibleReaderViewModel.bibleVersion?.language ?? "Korean"
            ttsManager.switchChapter(verses: bibleReaderViewModel.bibleVerseList, language: language)
        }
    }

    func switchChapter(verses: [BibleVerse], language: String, forcePlay: Bool = false) {
        ttsManager.switchChapter(verses: verses, language: language, forcePlay: forcePlay)
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
}
