//
//  RecordingRenameTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
@testable import HagaBible

// Unit tests for the recording-rename validation rule (RecordingsViewModel.normalizedTitle).
//
// The repository's updateRecording(_:) is intentionally not exercised here: it is a thin
// SwiftData modelContext.save(). The unit-test host already owns the app's SwiftData
// ModelContainer, and creating a second container for the same @Model types crashes the
// test process — which is why this target unit-tests pure logic and GRDB repositories, but
// not SwiftData repositories.
@Suite("Recording rename validation")
struct RecordingRenameTests {

    @Test("normalizedTitle trims surrounding whitespace")
    func normalizedTitle_trimsWhitespace() {
        #expect(RecordingsViewModel.normalizedTitle("  마가복음 1장  ") == "마가복음 1장")
    }

    @Test("normalizedTitle returns nil for empty or whitespace-only input")
    func normalizedTitle_rejectsEmpty() {
        #expect(RecordingsViewModel.normalizedTitle("") == nil)
        #expect(RecordingsViewModel.normalizedTitle("   ") == nil)
        #expect(RecordingsViewModel.normalizedTitle("\n\t ") == nil)
    }

    @Test("normalizedTitle keeps interior whitespace intact")
    func normalizedTitle_keepsInteriorSpaces() {
        #expect(RecordingsViewModel.normalizedTitle("요한 복음 3 장") == "요한 복음 3 장")
    }
}
