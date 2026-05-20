//
//  MockBookmarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation

final class MockBookmarkRepository: BookmarkRepository, @unchecked Sendable {
    private var storage: [Bookmark]
    private let lock = NSLock()

    init(seed: [Bookmark] = []) {
        self.storage = seed
    }

    func insert(_ bookmark: Bookmark) async throws {
        locked { storage.append(bookmark) }
    }

    func update(_ bookmark: Bookmark) async throws {
        locked {
            if let idx = storage.firstIndex(where: { $0.id == bookmark.id }) {
                storage[idx] = bookmark
            }
        }
    }

    func delete(id: UUID) async throws {
        locked { storage.removeAll { $0.id == id } }
    }

    func fetchAll(sortedBy: BookmarkSortOrder) async throws -> [Bookmark] {
        let snapshot = locked { storage }
        switch sortedBy {
        case .createdAtDesc:
            return snapshot.sorted { $0.createdAt > $1.createdAt }
        case .biblicalOrder:
            return snapshot.sorted {
                if $0.bookOrder != $1.bookOrder { return $0.bookOrder < $1.bookOrder }
                if $0.chapter != $1.chapter { return $0.chapter < $1.chapter }
                return $0.startVerse < $1.startVerse
            }
        }
    }

    func fetchForChapter(bookOrder: Int, chapter: Int) async throws -> [Bookmark] {
        let snapshot = locked { storage }
        return snapshot.filter { $0.bookOrder == bookOrder && $0.chapter == chapter }
    }

    func fetchFiltered(color: BookmarkColor?, bookCode: String?, keyword: String?) async throws -> [Bookmark] {
        let snapshot = locked { storage }
        return snapshot.filter { bookmark in
            if let color, bookmark.color != color { return false }
            if let bookCode, bookmark.bookCode != bookCode { return false }
            if let keyword, !keyword.isEmpty,
               !(bookmark.notes ?? "").localizedCaseInsensitiveContains(keyword) {
                return false
            }
            return true
        }
    }

    private func locked<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}

extension Bookmark {
    nonisolated static func previewSample(
        bookCode: String,
        bookOrder: Int,
        chapter: Int,
        startVerse: Int,
        endVerse: Int? = nil,
        color: BookmarkColor,
        notes: String? = nil,
        createdAt: Date = .now
    ) -> Bookmark {
        Bookmark(
            id: UUID(),
            bookCode: bookCode,
            bookOrder: bookOrder,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse ?? startVerse,
            color: color,
            notes: notes,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    nonisolated static let previewSet: [Bookmark] = {
        let now = Date()
        let day: TimeInterval = 86_400
        return [
            .previewSample(
                bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 1,
                color: .yellow, notes: "태초에 하나님이 천지를 창조하시니라",
                createdAt: now
            ),
            .previewSample(
                bookCode: "GEN", bookOrder: 1, chapter: 1, startVerse: 26, endVerse: 27,
                color: .blue, notes: "Image of God",
                createdAt: now.addingTimeInterval(-day)
            ),
            .previewSample(
                bookCode: "EXO", bookOrder: 2, chapter: 20, startVerse: 1, endVerse: 17,
                color: .green,
                notes: "The Ten Commandments — written by God's own finger on Mount Sinai. This long note should truncate to two lines in the row.",
                createdAt: now.addingTimeInterval(-2 * day)
            ),
            .previewSample(
                bookCode: "PSA", bookOrder: 19, chapter: 23, startVerse: 1, endVerse: 6,
                color: .pink,
                createdAt: now.addingTimeInterval(-3 * day)
            ),
            .previewSample(
                bookCode: "JHN", bookOrder: 43, chapter: 3, startVerse: 16,
                color: .orange, notes: "John 3:16",
                createdAt: now.addingTimeInterval(-4 * day)
            ),
            .previewSample(
                bookCode: "ROM", bookOrder: 45, chapter: 8, startVerse: 28,
                color: .yellow,
                createdAt: now.addingTimeInterval(-5 * day)
            ),
        ]
    }()
}

@MainActor
enum BookmarksPreviewFactory {
    nonisolated static let previewVerseTexts: [String: String] = [
        "GEN-1-1-1": "태초에 하나님이 천지를 창조하시니라",
        "GEN-1-26-27": "하나님이 가라사대 우리의 형상을 따라 우리의 모양대로 우리가 사람을 만들고…하나님이 자기 형상 곧 하나님의 형상대로 사람을 창조하시되 남자와 여자를 창조하시고",
        "EXO-20-1-17": "하나님이 이 모든 말씀으로 일러 가라사대 나는 너를 애굽 땅, 종 되었던 집에서 인도하여 낸 너의 하나님 여호와로라…",
        "PSA-23-1-6": "여호와는 나의 목자시니 내가 부족함이 없으리로다 그가 나를 푸른 풀밭에 누이시며 쉴 만한 물 가으로 인도하시는도다…",
        "JHN-3-16-16": "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라",
        "ROM-8-28-28": "우리가 알거니와 하나님을 사랑하는 자 곧 그 뜻대로 부르심을 입은 자들에게는 모든 것이 합력하여 선을 이루느니라",
        "GEN-1-1-31": "태초에 하나님이 천지를 창조하시니라…하나님이 그 지으신 모든 것을 보시니 보시기에 심히 좋았더라",
    ]

    static func makeViewModel(
        seed: [Bookmark] = Bookmark.previewSet,
        selectedColor: BookmarkColor? = nil,
        selectedBookCode: String? = nil,
        keyword: String = "",
        sortOrder: BookmarkSortOrder = .createdAtDesc,
        indicatorEnabled: Bool = true
    ) -> BookmarksViewModel {
        let viewModel = BookmarksViewModel(
            appState: AppState(),
            bookmarkRepository: MockBookmarkRepository(seed: seed),
            bibleRepository: MockBibleRepository.shared
        )
        viewModel.bookmarks = seed
        viewModel.availableBookCodes = Array(NSOrderedSet(array: seed.map(\.bookCode))) as? [String] ?? []
        viewModel.selectedColor = selectedColor
        viewModel.selectedBookCode = selectedBookCode
        viewModel.keyword = keyword
        viewModel.sortOrder = sortOrder
        viewModel.isBookmarkIndicatorEnabled = indicatorEnabled
        viewModel.verseTexts = Dictionary(uniqueKeysWithValues: seed.compactMap { b in
            let key = "\(b.bookCode)-\(b.chapter)-\(b.startVerse)-\(b.endVerse)"
            return previewVerseTexts[key].map { (b.id, $0) }
        })
        return viewModel
    }
}
