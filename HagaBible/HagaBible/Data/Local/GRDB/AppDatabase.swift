//
//  AppDatabase.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

import Foundation
import GRDB

final class AppDatabase {
    let dbPool: DatabasePool
    private let dbVersionKey = "dbVersion"
    private let currentDBVersion = "1.1"

    init() throws {
        let fileManager = FileManager.default
        let dbUrl = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HagaBibleDB.sqlite")
        
        let savedVersion = UserDefaults.standard.string(forKey: dbVersionKey)
        var shouldInitializeDB = false
        
        if savedVersion != currentDBVersion {
            shouldInitializeDB = true
            
            if fileManager.fileExists(atPath: dbUrl.path) {
                try? fileManager.removeItem(at: dbUrl)
            }
            
            guard let bundleURL = Bundle.main.url(forResource: "BibleDB", withExtension: "sqlite") else {
                throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "초기 DB 파일을 찾을 수 없습니다."])
            }
            try fileManager.copyItem(at: bundleURL, to: dbUrl)
        }

        dbPool = try DatabasePool(path: dbUrl.path)
        
        if shouldInitializeDB {
            try migrator.migrate(dbPool)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        return migrator
    }
}
