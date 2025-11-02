//
//  SearchHistory.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import Foundation
import SwiftData

@Model
class SearchHistory: Identifiable {
    @Attribute(.unique) var id: UUID
    var verse: BibleVerse
    var createdAt: Date
    
    init(verse: BibleVerse) {
        self.id = UUID()
        self.verse = verse
        self.createdAt = Date()
    }
}
