//
//  BibleVersionRecord.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

// Database - GRDB
import GRDB

struct BibleVersionRecord: Codable, FetchableRecord, PersistableRecord {
    let versionCode: String
    let versionName: String
    let language: String
    
    private enum CodingKeys: String, CodingKey {
        case versionCode = "version_code"
        case versionName = "version_name"
        case language = "language"
    }
}
