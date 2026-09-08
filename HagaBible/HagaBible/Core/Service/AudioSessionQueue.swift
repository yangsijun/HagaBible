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

    /// Runs `body` on the audio-session queue and resumes the caller once it has
    /// returned or thrown.
    static func run(_ body: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                continuation.resume(with: Result(catching: body))
            }
        }
    }
}
