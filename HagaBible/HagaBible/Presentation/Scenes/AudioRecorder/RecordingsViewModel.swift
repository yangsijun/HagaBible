//
//  RecordingsViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 9/2/25.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
class RecordingsViewModel {
    private let appState: AppState
    
    private let audioService: AudioService
    private let recordingRepository: RecordingRepository
    private let playbackManager: RecordingPlaybackManager

    var recordings: [Recording] = []

    init(
        appState: AppState,
        audioService: AudioService,
        recordingRepository: RecordingRepository,
        playbackManager: RecordingPlaybackManager
    ) {
        self.appState = appState

        self.audioService = audioService
        self.recordingRepository = recordingRepository
        self.playbackManager = playbackManager

        self.fetchRecordings()
    }

    // MARK: - Playback (forwarded to RecordingPlaybackManager)

    var playbackState: RecordingPlaybackState {
        playbackManager.playbackState
    }

    var playbackCurrentTime: TimeInterval {
        playbackManager.currentTime
    }

    var playbackDuration: TimeInterval {
        playbackManager.duration
    }

    func play(_ recording: Recording) {
        playbackManager.play(recording)
    }

    func togglePlayPause() {
        playbackManager.togglePlayPause()
    }

    func pausePlayback() {
        playbackManager.pause()
    }

    func stopPlayback() {
        playbackManager.stop()
    }

    func seek(to time: TimeInterval) {
        playbackManager.seek(to: time)
    }

    func skipForward() {
        playbackManager.skipForward()
    }

    func skipBackward() {
        playbackManager.skipBackward()
    }
    
    func fetchRecordings() {
        do {
            recordings = try recordingRepository.fetchRecordings()
            Logger.audio.debug("All recordings: \(self.audioService.getAllRecordings())")
        } catch {
            Logger.audio.error("Failed to fetch recordings: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        audioService.startRecording()
    }
    
    func pauseRecording() {
        audioService.pauseRecording()
    }
    
    func resumeRecording() {
        audioService.resumeRecording()
    }
    
    func stopRecording() {
        let newRecordingID = UUID()
        let bibleReferenceText = makeBibleReferenceText()
        
        audioService.stopRecording { url, duration in
            do {
                try self.recordingRepository.addRecording(
                    Recording(
                        id: newRecordingID,
                        title: bibleReferenceText,
                        bibleReference: bibleReferenceText,
                        transcript: nil,
                        duration: duration,
                        fileName: "\(url.lastPathComponent)",
                        createdAt: .now,
                        updatedAt: .now
                    )
                )
                Logger.audio.info("Recording saved with fileName: \(url.lastPathComponent)")
            } catch {
                Logger.audio.error("Failed to save recording: \(error.localizedDescription)")
            }
        }
        fetchRecordings()
    }
    
    /// Trims surrounding whitespace and returns `nil` for an empty result.
    /// Pure and side-effect free so the validation rule can be unit-tested
    /// without constructing the view model.
    nonisolated static func normalizedTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func renameRecording(_ recording: Recording, to newTitle: String) {
        guard let title = Self.normalizedTitle(newTitle), title != recording.title else {
            return
        }
        let previousTitle = recording.title
        let previousUpdatedAt = recording.updatedAt
        do {
            recording.title = title
            recording.updatedAt = .now
            try recordingRepository.updateRecording(recording)
            Logger.audio.info("Recording renamed to: \(title)")
        } catch {
            // Persist failed: roll back the in-memory @Model so the UI doesn't show
            // a "renamed" title that silently reverts on the next launch.
            recording.title = previousTitle
            recording.updatedAt = previousUpdatedAt
            Logger.audio.error("Failed to rename recording: \(error.localizedDescription)")
        }
        fetchRecordings()
    }

    func deleteRecording(_ recording: Recording) {
        do {
            Logger.audio.debug("All recordings before delete: \(self.audioService.getAllRecordings())")
            Logger.audio.debug("Deleting recording: \(recording.fileName)")
            audioService.deleteRecording(fileName: recording.fileName)
            try recordingRepository.deleteRecording(recording)
        } catch {
            Logger.audio.error("Failed to delete recording: \(error.localizedDescription)")
        }
        fetchRecordings()
    }
    
    func deleteRecording(at index: Int) {
        let recording = self.recordings[index]
        Logger.audio.debug("Deleting recording at index \(index): \(recording.title)")
        self.deleteRecording(recording)
    }
    
    var recordingTimeText: String {
        return audioService.getRecordingTimeText()
    }
    
    var isRecording: Bool {
        return audioService.isRecording
    }
    
    var recordingSamples: [CGFloat] {
        return audioService.audioSamples
    }
    
    func makeBibleReferenceText() -> String {
        var bibleReferenceText: String = ""
        
        let bibleVersion = appState.bibleReaderState.bibleVersion
        let bibleBook = appState.bibleReaderState.bibleBook
        let bibleChapter = appState.bibleReaderState.bibleChapter
        
        guard let bibleVersion, let bibleBook, let bibleChapter else {
            return String(localized: "Bible Recording")
        }
        
        bibleReferenceText = "\(bibleBook.bookName) \(bibleChapter.chapter)"
        bibleReferenceText += getChapterCounterNoun(bookCode: bibleBook.bookCode, versionLanguage: bibleVersion.language)
        
        return bibleReferenceText
    }
}
