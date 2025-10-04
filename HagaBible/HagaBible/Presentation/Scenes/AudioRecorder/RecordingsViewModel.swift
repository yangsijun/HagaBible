//
//  RecordingsViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 9/2/25.
//

import Observation
import Foundation

@Observable
@MainActor
class RecordingsViewModel {
    private let appState: AppState
    
    private let audioService: AudioService
    private let recordingRepository: RecordingRepository
    
    var recordings: [Recording] = []
    
    init(appState: AppState, audioService: AudioService, recordingRepository: RecordingRepository) {
        self.appState = appState
        
        self.audioService = audioService
        self.recordingRepository = recordingRepository
        
        self.fetchRecordings()
    }
    
    func fetchRecordings() {
        do {
            recordings = try recordingRepository.fetchRecordings()
            print(audioService.getAllRecordings())
        } catch {
            print("Failed to fetch recordings: \(error)")
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
                print("Recording에 저장된 fileName: \(url.lastPathComponent)")
            } catch {
                print("녹음 저장 실패: \(error)")
            }
        }
        fetchRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        do {
            print(audioService.getAllRecordings())
            print(recording.fileName)
            audioService.deleteRecording(fileName: recording.fileName)
            try recordingRepository.deleteRecording(recording)
        } catch {
            print("녹음 삭제 실패: \(error)")
        }
        fetchRecordings()
    }
    
    func deleteRecording(at index: Int) {
        let recording = self.recordings[index]
        print(recording.title)
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
            return "성경 녹음"
        }
        
        if bibleVersion.language == "Korean" {
            bibleReferenceText = "\(bibleBook.bookName) \(bibleChapter.chapter)장"
        } else {
            bibleReferenceText = "\(bibleBook.bookName) \(bibleChapter.chapter)"
        }
        
        return bibleReferenceText
    }
}
