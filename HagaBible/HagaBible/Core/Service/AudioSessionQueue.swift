//
//  AudioSessionQueue.swift
//  HagaBible
//
//  Created by 양시준 on 9/8/26.
//

import Foundation

/// Runs `AVAudioSession` configuration off the main thread.
///
/// `setCategory`/`setActive` are synchronous round trips to the audio server, and
/// Xcode 26 flags every main-thread call as an "AVAudioSession Hang Risk": the call
/// blocks until the server answers, which takes noticeably long when another app's
/// audio has to be stopped first. The non-blocking
/// `activate/deactivate(options:completionHandler:)` API only exists from iOS 27, so
/// with an iOS 26 deployment target the calls are hopped onto this one serial queue
/// instead and callers `await` the result. Serial on purpose: an activation issued
/// after a deactivation must also reach the server after it.
nonisolated enum AudioSessionQueue {
    private static let queue = DispatchQueue(label: "com.hagabible.audio-session", qos: .userInitiated)

    /// Runs `body` on the audio-session queue and resumes the caller with its result
    /// once it has returned or thrown.
    ///
    /// Also the place for `AVAudioPlayer`/`AVAudioRecorder` setup and transport:
    /// `prepareToPlay()`, `play()` after a stop or a natural finish, and `record()` on a
    /// fresh recorder allocate the object's audio queue, which re-activates the session
    /// on the calling thread (same hang risk). Hand the object back with `AudioObjectBox`.
    static func run<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
            queue.async {
                continuation.resume(with: Result(catching: body))
            }
        }
    }
}

/// Carries a non-`Sendable` AVFoundation object (`AVAudioPlayer`, `AVAudioRecorder`)
/// across the hop to and from `AudioSessionQueue`.
///
/// Safe only because the object is touched from one place at a time: built and started
/// on the queue, then handed to the main actor, which owns it from there. Any later call
/// that goes back through the queue must not overlap with main-actor use of the object.
nonisolated struct AudioObjectBox<Object: AnyObject>: @unchecked Sendable {
    let object: Object

    init(_ object: Object) {
        self.object = object
    }
}
