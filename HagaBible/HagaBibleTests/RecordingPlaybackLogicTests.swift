//
//  RecordingPlaybackLogicTests.swift
//  HagaBibleTests
//
//  Created by 양시준 on 6/16/26.
//
// Unit tests for the pure playback math in RecordingPlaybackManager
// (timeString / clampedTime / skipTarget). These are nonisolated static helpers,
// so they need no AVAudioPlayer, no SwiftData ModelContainer, and no main actor —
// which keeps the shared test process safe (see the SwiftData-container crash note).

import Testing
import Foundation
@testable import HagaBible

@Suite("Recording playback logic")
struct RecordingPlaybackLogicTests {

    // MARK: - timeString

    @Test("timeString formats minutes and seconds as m:ss")
    func timeString_formatsMinutesSeconds() {
        #expect(RecordingPlaybackManager.timeString(0) == "0:00")
        #expect(RecordingPlaybackManager.timeString(5) == "0:05")
        #expect(RecordingPlaybackManager.timeString(65) == "1:05")
        #expect(RecordingPlaybackManager.timeString(125) == "2:05")
    }

    @Test("timeString lets minutes exceed 59 (no hour rollover)")
    func timeString_longDuration() {
        #expect(RecordingPlaybackManager.timeString(3661) == "61:01")
    }

    @Test("timeString renders non-finite and negative input as 0:00")
    func timeString_invalidInput() {
        #expect(RecordingPlaybackManager.timeString(-3) == "0:00")
        #expect(RecordingPlaybackManager.timeString(.nan) == "0:00")
        #expect(RecordingPlaybackManager.timeString(.infinity) == "0:00")
    }

    @Test("timeString truncates fractional seconds")
    func timeString_truncatesFraction() {
        #expect(RecordingPlaybackManager.timeString(9.99) == "0:09")
    }

    // MARK: - clampedTime

    @Test("clampedTime keeps a value inside the file bounds")
    func clampedTime_withinBounds() {
        #expect(RecordingPlaybackManager.clampedTime(30, duration: 100) == 30)
    }

    @Test("clampedTime clamps below 0 and above duration")
    func clampedTime_outOfBounds() {
        #expect(RecordingPlaybackManager.clampedTime(-5, duration: 100) == 0)
        #expect(RecordingPlaybackManager.clampedTime(150, duration: 100) == 100)
    }

    @Test("clampedTime returns 0 when duration is unknown or zero")
    func clampedTime_zeroDuration() {
        #expect(RecordingPlaybackManager.clampedTime(30, duration: 0) == 0)
    }

    // MARK: - skipTarget

    @Test("skipTarget moves forward and backward within bounds")
    func skipTarget_withinBounds() {
        #expect(RecordingPlaybackManager.skipTarget(current: 30, delta: 15, duration: 100) == 45)
        #expect(RecordingPlaybackManager.skipTarget(current: 30, delta: -15, duration: 100) == 15)
    }

    @Test("skipTarget clamps forward at duration and backward at 0")
    func skipTarget_clampsAtEdges() {
        #expect(RecordingPlaybackManager.skipTarget(current: 95, delta: 15, duration: 100) == 100)
        #expect(RecordingPlaybackManager.skipTarget(current: 5, delta: -15, duration: 100) == 0)
    }
}
