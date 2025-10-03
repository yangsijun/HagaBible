//
//  AudioService.swift
//  HagaBible
//
//  Created by 양시준 on 8/29/25.
//

import Foundation
import AVFoundation

enum AudioServiceError: Error {
    case recorderNotAvailable
    case sessionSetupFailed
}

@MainActor
@Observable
class AudioService {
    var isRecording = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    
    private var monitoringTask: Task<Void, Never>?
    var audioSamples: [CGFloat] = []
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
            AVAudioApplication.requestRecordPermission(completionHandler: { isGranted in
                print("Recording permission isGranted=\(isGranted)")
            })
        } catch {
            print("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            
            audioRecorder?.record()
            isRecording = true
            
            monitoringTask = Task {
                // isRecording이 true인 동안 계속 반복
                while self.isRecording {
                    self.updateAudioSamples()
                    // 0.1초 대기 (Timer의 역할 대체)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            print("Recording started with async monitoring.")
        } catch {
            print("녹음 시작 실패: \(error.localizedDescription)")
            isRecording = false
        }
    }
    
    func resumeRecording() {
        guard let audioRecorder = audioRecorder else {
            return
        }
        
        audioRecorder.record()
    }
    
    func pauseRecording() {
        guard let audioRecorder = audioRecorder else {
            return
        }
        
        audioRecorder.pause()
    }
    
    func stopRecording(completion: @escaping (URL, TimeInterval) -> Void) {
        guard let recorder = audioRecorder else {
            return
        }
        
        let audioURL = recorder.url
        let duration = recorder.currentTime
        
        recorder.stop()
        self.audioRecorder = nil
        isRecording = false
        
        audioSamples.removeAll()
        
        completion(audioURL, duration)
    }
    
    func deleteRecording(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            print("삭제할 파일을 찾았습니다: \(url.lastPathComponent)")
            print("녹음 파일 삭제 시작")
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("녹음 파일 삭제 실패: \(error.localizedDescription)")
            }
        } else {
            print("삭제할 파일을 찾을 수 없습니다. 경로: \(url.path)")
        }
    }
    
    func getAllRecordings() -> [URL] {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: []) else {
            return []
        }
        
        return fileURLs
    }
    
    func getRecordingTimeText() -> String {
        guard let audioRecorder = audioRecorder else {
            return "00:00"
        }
        
        let duration = Int(audioRecorder.currentTime)
        let minutes = duration / 60
        let seconds = duration % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func updateAudioSamples() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        
        let power = recorder.averagePower(forChannel: 0)
        let normalizedPower = CGFloat((160 + power) / 160)
        
        if (normalizedPower > 0.75) {
            audioSamples.append((normalizedPower - 0.75) * 4)
        } else {
            audioSamples.append(0.0)
        }
        print(normalizedPower)
        
        if audioSamples.count > 50 {
            audioSamples.removeFirst()
        }
    }
}
