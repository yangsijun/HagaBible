//
//  AudioServiceRecordingStateProvider.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import Foundation

final class AudioServiceRecordingStateProvider: RecordingStateProvider {
    private let audioServiceProvider: () -> AudioService

    init(audioServiceProvider: @escaping () -> AudioService = {
        DIContainer.shared.resolve(type: AudioService.self)
    }) {
        self.audioServiceProvider = audioServiceProvider
    }

    var isRecording: Bool {
        audioServiceProvider().isRecording
    }
}
