//
//  BibleVersion.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

struct BibleVersion: Codable, Identifiable {
    let id: String
    let language: String
    let name: String
    var isDownloaded: Bool
}
