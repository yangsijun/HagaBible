//
//  Recording.swift
//  HagaBible
//
//  Created by 양시준 on 7/3/25.
//

import Foundation
import SwiftData

@Model
class Recording: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var bibleReference: String
    var transcript: String?
    var duration: TimeInterval
    var fileURL: URL
    var createdAt: Date
    var updatedAt: Date
    
    var folder: RecordingFolder?
    
    init(
        id: UUID = UUID(),
        title: String,
        bibleReference: String,
        transcript: String? = nil,
        duration: TimeInterval,
        fileURL: URL,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.bibleReference = bibleReference
        self.transcript = transcript
        self.duration = duration
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
