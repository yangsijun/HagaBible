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
    private let audioService: AudioService
    private let recordingRepository: RecordingRepository
    
    var recordings: [Recording] = []
    
    init(audioService: AudioService, recordingRepository: RecordingRepository) {
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
        audioService.stopRecording { url, duration in
            do {
                try self.recordingRepository.addRecording(
                    Recording(
                        id: newRecordingID,
                        title: "새 녹음",
                        bibleReference: "temp",
                        transcript: nil,
                        duration: duration,
                        fileURL: url,
                        createdAt: .now,
                        updatedAt: .now
                    )
                )
                print("Recording에 저장된 url: \(url)")
            } catch {
                print("녹음 저장 실패: \(error)")
            }
        }
        fetchRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        do {
            print(audioService.getAllRecordings())
            print(recording.fileURL)
            audioService.deleteRecording(url: recording.fileURL)
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
}
