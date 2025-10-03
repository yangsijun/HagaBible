//
//  RecordingFolder.swift
//  HagaBible
//
//  Created by 양시준 on 9/12/25.
//

import Foundation
import SwiftData

@Model
final class RecordingFolder {
    @Attribute(.unique) var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \Recording.folder)
    var recordings: [Recording]? = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
