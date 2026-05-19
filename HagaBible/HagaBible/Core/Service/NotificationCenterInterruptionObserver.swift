//
//  NotificationCenterInterruptionObserver.swift
//  HagaBible
//
//  Created by OpenAI on 4/10/26.
//

import AVFoundation
import Foundation

final class NotificationCenterInterruptionObserver: InterruptionObservable {
    @discardableResult
    func addInterruptionObserver(handler: @escaping (Notification) -> Void) -> NSObjectProtocol {
#if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil,
            using: handler
        )
#else
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TTSInterruptionUnsupportedPlatform"),
            object: nil,
            queue: nil,
            using: handler
        )
#endif
    }

    func removeObserver(_ observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
    }
}
