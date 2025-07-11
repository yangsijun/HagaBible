//
//  AppDatabase.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init() throws {
        let fileManager = FileManager.default
        let dbUrl = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HagaBibleDB.sqlite")
        
        // Documents에 DB 파일이 없으면 번들에서 복사
        if !fileManager.fileExists(atPath: dbUrl.path) {
            guard let bundleURL = Bundle.main.url(forResource: "BibleDB", withExtension: "sqlite") else {
                throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "초기 DB 파일을 찾을 수 없습니다."])
            }
            try fileManager.copyItem(at: bundleURL, to: dbUrl)
        }

        dbQueue = try DatabaseQueue(path: dbUrl.path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        return migrator
    }
}
