//
//  Recoding.swift
//  HagaBible
//
//  Created by 양시준 on 7/3/25.
//

import Foundation

struct Recording: Codable, Identifiable {
    let id: UUID
    let bibleReference: String
    let filePath: String
    let duration: TimeInterval
    let createdAt: Date
}
