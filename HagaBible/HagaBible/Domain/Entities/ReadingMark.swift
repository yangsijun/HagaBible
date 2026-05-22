//
//  ReadingMark.swift
//  HagaBible
//
//  Created by 양시준 on 5/21/26.
//

import Foundation

/// A per-chapter "have I read this" mark for the reading checklist (성경읽기표).
/// No reading plan or schedule — just whether a given chapter has been read.
struct ReadingMark: Equatable, Hashable, Sendable, Codable, Identifiable {
    let id: UUID
    let bookCode: String    // version-independent identity (e.g. "PSA"); the sync key
    let bookOrder: Int      // 1–66, denormalized for biblical-order sorting
    let chapter: Int
    let isRead: Bool
    let createdAt: Date
    let updatedAt: Date
}
