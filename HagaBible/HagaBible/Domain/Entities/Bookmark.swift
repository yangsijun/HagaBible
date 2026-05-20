//
//  Bookmark.swift
//  HagaBible
//
//  Created by 양시준 on 5/19/26.
//

import Foundation

struct Bookmark: Equatable, Hashable, Sendable, Codable, Identifiable {
    let id: UUID
    let bookCode: String
    let bookOrder: Int
    let chapter: Int
    let startVerse: Int
    let endVerse: Int
    let color: BookmarkColor
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}
