//
//  AudioService.swift
//  HagaBible
//
//  Created by 양시준 on 8/29/25.
//

import AVFoundation
import Foundation
import OSLog

enum AudioServiceError: Error {
    case recorderNotAvailable
    case sessionSetupFailed
}

@MainActor
@Observable
class AudioService {
    var isRecording = false
    
    private var audioRecorder: AVAudioRecorder?
    
    private var monitoringTask: Task<Void, Never>?
    var audioSamples: [CGFloat] = []
    
    init() {
        // Only request mic permission up front. Each feature sets its own audio session
        // category at the moment it's used. Activating .playAndRecord at launch forced
        // Bluetooth into HFP, which made TTS's first .playback render switch the route to
        // A2DP (a stalling delay) and left the session output-only so recording after TTS
        // captured no input until an app relaunch.
        AVAudioApplication.requestRecordPermission(completionHandler: { isGranted in
            Logger.audio.debug("Recording permission granted: \(isGranted)")
        })
    }
    
//    private func getDocumentsDirectory() -> URL {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
    
    func startRecording() {
        // Activate a record-capable session right before recording. TTS may have switched
        // the shared session to .playback (output only), so re-assert .playAndRecord every
        // time or the recording captures no input until an app relaunch.
        // .allowBluetoothA2DP keeps output high quality; input stays on the built-in mic
        // (matches the recording-playback session).
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            Logger.audio.error("Failed to activate recording session: \(error.localizedDescription)")
        }

        let audioFilename = FileManager.documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
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
            Logger.audio.debug("Recording started")
        } catch {
            Logger.audio.error("Failed to start recording: \(error.localizedDescription)")
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
    
    func deleteRecording(fileName: String) {
        let url = FileManager.documentsDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {
            Logger.audio.debug("Deleting recording file: \(url.lastPathComponent)")
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Logger.audio.error("Failed to delete recording: \(error.localizedDescription)")
            }
        } else {
            Logger.audio.warning("Recording file not found: \(url.path, privacy: .public)")
        }
    }
    
    func getAllRecordings() -> [URL] {
        let fileManager = FileManager.default
        let documentsURL = FileManager.documentsDirectory
        
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
        
        if audioSamples.count > 50 {
            audioSamples.removeFirst()
        }
    }
}
