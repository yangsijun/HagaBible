//
//  BookmarkRepository.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation

enum BookmarkSortOrder: Sendable {
    case createdAtDesc
    case biblicalOrder
}

protocol BookmarkRepository: Sendable {
    func insert(_ bookmark: Bookmark) async throws
    func update(_ bookmark: Bookmark) async throws
    func delete(id: UUID) async throws
    func fetchAll(sortedBy: BookmarkSortOrder) async throws -> [Bookmark]
    func fetchForChapter(bookOrder: Int, chapter: Int) async throws -> [Bookmark]
    func fetchFiltered(color: BookmarkColor?, bookCode: String?, keyword: String?) async throws -> [Bookmark]
}
