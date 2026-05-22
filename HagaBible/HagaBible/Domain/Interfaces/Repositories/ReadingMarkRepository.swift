//
//  ReadingMarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import Foundation

protocol ReadingMarkRepository: Sendable {
    /// All live (non-tombstoned) reading marks, biblical order.
    func fetchAll() async throws -> [ReadingMark]
    /// Upsert the read state of a single chapter (identity: book_code + chapter).
    func setRead(bookCode: String, bookOrder: Int, chapter: Int, isRead: Bool) async throws
    /// Upsert several chapters of one book in a single transaction (drag-paint).
    func setRead(bookCode: String, bookOrder: Int, chapters: [Int], isRead: Bool) async throws
    /// Marks every chapter unread (keeps the rows so re-marking reuses them).
    func resetAll() async throws
}
