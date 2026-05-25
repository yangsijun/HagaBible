//
//  BibleVersion.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

struct BibleVersion: Equatable, Hashable, Codable {
    let versionCode: String
    let versionName: String
    /// Short label for compact contexts (e.g. the "Both" export header). Korean
    /// versions reuse their full `versionName`; English versions use `versionCode`.
    let versionShortName: String
    let language: String
    var isDownloaded: Bool
}
