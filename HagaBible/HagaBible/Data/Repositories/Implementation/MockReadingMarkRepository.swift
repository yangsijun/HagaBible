//
//  MockReadingMarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import Foundation

final class MockReadingMarkRepository: ReadingMarkRepository, @unchecked Sendable {
    private var storage: [ReadingMark]
    private let lock = NSLock()

    /// When true, every write throws — lets tests exercise optimistic-revert paths.
    var failOnWrite = false

    /// Seed with a set of (bookCode, bookOrder, chapter) triples that start as read.
    init(read: [(bookCode: String, bookOrder: Int, chapter: Int)] = []) {
        let now = Date()
        self.storage = read.map {
            ReadingMark(
                id: UUID(),
                bookCode: $0.bookCode,
                bookOrder: $0.bookOrder,
                chapter: $0.chapter,
                isRead: true,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    func fetchAll() async throws -> [ReadingMark] {
        locked {
            storage.sorted {
                $0.bookOrder != $1.bookOrder ? $0.bookOrder < $1.bookOrder : $0.chapter < $1.chapter
            }
        }
    }

    func setRead(bookCode: String, bookOrder: Int, chapter: Int, isRead: Bool) async throws {
        try await setRead(bookCode: bookCode, bookOrder: bookOrder, chapters: [chapter], isRead: isRead)
    }

    func setRead(bookCode: String, bookOrder: Int, chapters: [Int], isRead: Bool) async throws {
        if failOnWrite { throw MockError.writeFailed }
        locked {
            for chapter in chapters {
                if let idx = storage.firstIndex(where: { $0.bookCode == bookCode && $0.chapter == chapter }) {
                    let existing = storage[idx]
                    storage[idx] = ReadingMark(
                        id: existing.id,
                        bookCode: bookCode,
                        bookOrder: bookOrder,
                        chapter: chapter,
                        isRead: isRead,
                        createdAt: existing.createdAt,
                        updatedAt: Date()
                    )
                } else {
                    storage.append(
                        ReadingMark(
                            id: UUID(),
                            bookCode: bookCode,
                            bookOrder: bookOrder,
                            chapter: chapter,
                            isRead: isRead,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                    )
                }
            }
        }
    }

    func resetAll() async throws {
        if failOnWrite { throw MockError.writeFailed }
        locked {
            storage = storage.map { mark in
                guard mark.isRead else { return mark }
                return ReadingMark(
                    id: mark.id,
                    bookCode: mark.bookCode,
                    bookOrder: mark.bookOrder,
                    chapter: mark.chapter,
                    isRead: false,
                    createdAt: mark.createdAt,
                    updatedAt: Date()
                )
            }
        }
    }

    enum MockError: Error { case writeFailed }

    private func locked<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}

@MainActor
enum ReadingChecklistPreviewFactory {
    static func makeViewModel(
        books: [BibleBook]? = nil,
        readByBook: [String: Set<Int>] = ["GEN": [1, 2, 3, 4, 5], "EXO": [1]]
    ) -> ReadingChecklistViewModel {
        let resolvedBooks = books ?? (try? MockBibleRepository.shared.fetchBibleBookList(versionCode: "KRV")) ?? []
        let viewModel = ReadingChecklistViewModel(
            appState: AppState(),
            readingMarkRepository: MockReadingMarkRepository(),
            bibleRepository: MockBibleRepository.shared
        )
        viewModel.books = resolvedBooks
        viewModel.readChapters = readByBook
        return viewModel
    }
}
