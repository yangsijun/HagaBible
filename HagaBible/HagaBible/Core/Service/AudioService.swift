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
    /// A start is in flight: the record-capable session is being activated off the
    /// main thread and the recorder has not been created yet. Guards against a second
    /// tap creating a second recorder, and lets stopRecording cancel a start that has
    /// not produced a recorder yet.
    private var isStartPending = false
    
    private var monitoringTask: Task<Void, Never>?
    var audioSamples: [CGFloat] = []
    
    init() {
        // No audio work at launch. Recording is an opt-in ("Labs") feature, so the mic
        // permission prompt is deferred to requestMicrophonePermissionIfNeeded() — called
        // when the user enables recording — instead of firing on every app launch. The
        // .playAndRecord session is likewise activated lazily in startRecording().
        // (Activating audio at launch previously forced Bluetooth into HFP and prompted
        // for the mic before the user ever used recording.)
    }

    /// Requests microphone permission. Called when the user turns on the opt-in
    /// recording feature, so the system prompt appears then — not at app launch.
    /// `requestRecordPermission` is idempotent: if permission is already determined it
    /// reports the status without prompting again.
    func requestMicrophonePermissionIfNeeded() {
        AVAudioApplication.requestRecordPermission(completionHandler: { isGranted in
            Logger.audio.debug("Recording permission granted: \(isGranted)")
        })
    }
    
//    private func getDocumentsDirectory() -> URL {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
    
    func startRecording() {
        guard !isRecording, !isStartPending, audioRecorder == nil else { return }
        isStartPending = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Activate a record-capable session right before recording. TTS may have
            // switched the shared session to .playback (output only), so re-assert
            // .playAndRecord every time or the recording captures no input until an app
            // relaunch. .allowBluetoothA2DP keeps output high quality; input stays on the
            // built-in mic (matches the recording-playback session). Runs off the main
            // thread (AudioSessionQueue): setCategory/setActive block on the audio server.
            do {
                try await AudioSessionQueue.run {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
                    try session.setActive(true)
                }
            } catch {
                Logger.audio.error("Failed to activate recording session: \(error.localizedDescription)")
            }
            // stopRecording() ran while the session was activating: the user no longer
            // wants a recording, so don't create the recorder at all.
            guard self.isStartPending else { return }
            await self.beginRecording()
        }
    }

    /// Creates the recorder on the now-active session and starts capturing.
    ///
    /// Built and started on AudioSessionQueue, not here: `record()` on a fresh recorder
    /// allocates the capture queue (`prepareToRecordQueue`), which re-activates the
    /// session on the calling thread — the same blocking call startRecording keeps off
    /// main. `pause()`, `record()` after a pause, `updateMeters()` and `stop()` do not
    /// touch the session, so they stay on the main actor.
    private func beginRecording() async {
        let audioFilename = FileManager.documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            let (box, started) = try await AudioSessionQueue.run {
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                recorder.isMeteringEnabled = true
                let started = recorder.record()
                return (AudioObjectBox(recorder), started)
            }
            let recorder = box.object

            // stopRecording() ran while the recorder was being built: nobody wants this
            // recording, so drop it and its (near-empty) file.
            guard self.isStartPending else {
                recorder.stop()
                try? FileManager.default.removeItem(at: audioFilename)
                return
            }
            self.isStartPending = false

            audioRecorder = recorder
            isRecording = true
            if !started {
                Logger.audio.error("AVAudioRecorder.record() returned false")
            }
            
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
            self.isStartPending = false
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
        // Stop tapped before the deferred start created a recorder: cancel the start.
        isStartPending = false
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
