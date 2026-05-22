//
//  ReadingChecklistLogicTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
@testable import HagaBible

// MARK: - ChapterRangePaint (pure range/diff math)

@Suite("ChapterRangePaint Tests")
struct ChapterRangePaintTests {

    @Test("growing the range paints each newly entered chapter with the target")
    func test_grow_paintsNewChapters() {
        var paint = ChapterRangePaint(anchor: 3, target: true)

        let first = paint.update(to: 3) { _ in false }
        #expect(first == [.init(chapter: 3, isRead: true)])
        #expect(paint.range == [3])

        let grown = paint.update(to: 5) { _ in false }
        #expect(grown == [.init(chapter: 4, isRead: true), .init(chapter: 5, isRead: true)])
        #expect(paint.range == [3, 4, 5])
        #expect(paint.changedChapters == [3, 4, 5])
    }

    @Test("range fills by chapter number regardless of drag direction")
    func test_grow_downwardFromAnchor() {
        var paint = ChapterRangePaint(anchor: 6, target: true)
        _ = paint.update(to: 6) { _ in false }

        let ops = paint.update(to: 3) { _ in false }
        #expect(ops == [.init(chapter: 3, isRead: true),
                        .init(chapter: 4, isRead: true),
                        .init(chapter: 5, isRead: true)])
        #expect(paint.range == [3, 4, 5, 6])
    }

    @Test("shrinking the range reverts dropped chapters to their pre-drag state")
    func test_shrink_revertsDroppedChapters() {
        var paint = ChapterRangePaint(anchor: 1, target: true)
        _ = paint.update(to: 1) { _ in false }
        _ = paint.update(to: 4) { _ in false }   // 1...4 painted read

        let ops = paint.update(to: 2) { _ in false }
        #expect(ops == [.init(chapter: 3, isRead: false), .init(chapter: 4, isRead: false)])
        #expect(paint.range == [1, 2])
        #expect(paint.changedChapters == [1, 2])
    }

    @Test("a mixed-state range paints uniformly but persists only changed chapters")
    func test_mixedState_uniformPaint_changedOnly() {
        // Chapter 2 is already read; 1 and 3 are not. Anchor (1) is unread → mark read.
        let originals: [Int: Bool] = [1: false, 2: true, 3: false]
        var paint = ChapterRangePaint(anchor: 1, target: true)

        _ = paint.update(to: 1) { originals[$0] ?? false }
        let ops = paint.update(to: 3) { originals[$0] ?? false }

        // Every entered cell gets target=true (uniform), including the already-read 2.
        #expect(ops.contains(.init(chapter: 2, isRead: true)))
        #expect(ops.contains(.init(chapter: 3, isRead: true)))
        // But only chapters whose final state differs from the original are persisted.
        #expect(paint.changedChapters == [1, 3])
    }

    @Test("anchor read → drag unmarks, persisting only chapters that were read")
    func test_unmarkAction() {
        let originals: [Int: Bool] = [2: true, 3: true, 4: false]
        var paint = ChapterRangePaint(anchor: 2, target: false)

        _ = paint.update(to: 2) { originals[$0] ?? false }
        _ = paint.update(to: 4) { originals[$0] ?? false }

        // 4 was already unread, so it isn't a change; 2 and 3 flip read→unread.
        #expect(paint.changedChapters == [2, 3])
    }
}

// MARK: - ReadingChecklistViewModel (optimistic update + revert)

@MainActor
@Suite("ReadingChecklistViewModel Tests")
struct ReadingChecklistViewModelTests {

    private let gen = BibleBook(bookCode: "GEN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV")

    private func makeViewModel(_ mock: MockReadingMarkRepository) -> ReadingChecklistViewModel {
        let vm = ReadingChecklistViewModel(
            appState: AppState(),
            readingMarkRepository: mock,
            bibleRepository: MockBibleRepository.shared
        )
        vm.books = [gen]
        return vm
    }

    /// Polls an async condition until it holds or the timeout elapses — used to wait
    /// for the view model's fire-and-forget persistence Task to settle.
    private func eventually(
        timeout: Duration = .seconds(2),
        _ condition: () async throws -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while true {
            if try await condition() { return }
            if ContinuousClock.now - start > timeout {
                Issue.record("condition not met within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("toggleRead optimistically updates local state immediately")
    func test_toggleRead_optimistic() {
        let vm = makeViewModel(MockReadingMarkRepository())

        vm.toggleRead(book: gen, chapter: 1)

        #expect(vm.isRead(bookCode: "GEN", chapter: 1))
        #expect(vm.readCount(forBook: gen) == 1)
        #expect(vm.overallRead == 1)
    }

    @Test("toggleRead persists to the repository")
    func test_toggleRead_persists() async throws {
        let mock = MockReadingMarkRepository()
        let vm = makeViewModel(mock)

        vm.toggleRead(book: gen, chapter: 1)

        try await eventually {
            try await mock.fetchAll().contains { $0.bookCode == "GEN" && $0.chapter == 1 && $0.isRead }
        }
    }

    @Test("toggleRead reverts optimistic state when the write fails")
    func test_toggleRead_revertsOnFailure() async throws {
        let mock = MockReadingMarkRepository()
        mock.failOnWrite = true
        let vm = makeViewModel(mock)

        vm.toggleRead(book: gen, chapter: 1)
        #expect(vm.isRead(bookCode: "GEN", chapter: 1))   // optimistic

        // The failed write triggers a reload from persisted truth (empty) → reverts.
        try await eventually { !vm.isRead(bookCode: "GEN", chapter: 1) }
    }

    @Test("resetAll optimistically clears all read state")
    func test_resetAll_optimistic() {
        let vm = makeViewModel(MockReadingMarkRepository())
        vm.readChapters = ["GEN": [1, 2, 3]]

        vm.resetAll()

        #expect(vm.overallRead == 0)
        #expect(!vm.isRead(bookCode: "GEN", chapter: 1))
    }

    @Test("persistDragSelection writes the whole range and reflects locally")
    func test_persistDragSelection() async throws {
        let mock = MockReadingMarkRepository()
        let vm = makeViewModel(mock)

        // Mimic the grid's preview then commit.
        for chapter in 1...5 { vm.previewSetRead(bookCode: "GEN", chapter: chapter, isRead: true) }
        #expect(vm.readCount(forBook: gen) == 5)

        vm.persistDragSelection(book: gen, chapters: [1, 2, 3, 4, 5], isRead: true)

        try await eventually {
            try await mock.fetchAll().filter { $0.bookCode == "GEN" && $0.isRead }.count == 5
        }
    }
}
