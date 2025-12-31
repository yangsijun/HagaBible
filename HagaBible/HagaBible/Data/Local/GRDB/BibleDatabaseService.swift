//
//  BibleDatabaseService.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

import Foundation
import GRDB

final class BibleDatabaseService {
    private(set) var dbPool: DatabasePool?
    
    private let lock = NSLock()
    
    private let dbVersionKey = "dbVersion"
    private let currentDBVersion = "1.4"
    
    private var mainDatabaseURL: URL {
        try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HagaBibleDB.sqlite")
    }

    init() throws {
        do {
            try setupMainDatabaseFile() // 1. 메인 파일 준비
            try reloadDatabasePool()    // 2. Pool 연결 (Attach 포함)
        } catch {
            print("Database Initialization Error: \(error)")
            throw error
        }
    }
    
    // MARK: - 1. 메인 DB 파일 준비 (기존 로직 유지)
    /// 번들에서 초기 DB 파일을 복사하거나 버전을 체크하여 업데이트합니다.
    private func setupMainDatabaseFile() throws {
        let fileManager = FileManager.default
        let dbUrl = mainDatabaseURL
        
        let savedVersion = UserDefaults.standard.string(forKey: dbVersionKey)
        var shouldReplaceDB = false
        
        // 버전이 다르면 교체 플래그 설정
        if savedVersion != currentDBVersion {
            shouldReplaceDB = true
        }
        
        // 파일이 아예 없어도 복사해야 함
        if !fileManager.fileExists(atPath: dbUrl.path) {
            shouldReplaceDB = true
        }
        
        if shouldReplaceDB {
            print("DB 버전 변경 또는 파일 없음. 초기화 진행...")
            
            // 기존 파일 제거
            if fileManager.fileExists(atPath: dbUrl.path) {
                try fileManager.removeItem(at: dbUrl)
            }
            
            // 번들에서 복사
            guard let bundleURL = Bundle.main.url(forResource: "BibleDB", withExtension: "sqlite") else {
                // 번들에 파일이 없다면, 빈 DB라도 생성하도록 로직을 유연하게 가져갈 수도 있음
                // 여기서는 User 요구사항대로 Error throw
                throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundle에서 초기 BibleDB.sqlite를 찾을 수 없습니다."])
            }
            try fileManager.copyItem(at: bundleURL, to: dbUrl)
            
            // 버전 갱신 저장
            UserDefaults.standard.set(currentDBVersion, forKey: dbVersionKey)
        }
    }
    
    // MARK: - 2. Pool 재로딩 (ODR Attach 통합 핵심 로직)
    /// 다운로드된 성경 파일들을 스캔하여 DB Pool을 재설정합니다.
    func reloadDatabasePool() throws {
        lock.lock()
        defer { lock.unlock() }
        
        // 기존 연결 해제
        dbPool = nil
        
        // A. 다운로드된 외부 성경 파일 스캔
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Documents 폴더 내의 Bible_*.sqlite 파일들을 찾음
        var tempAttachedConfigs: [(path: String, alias: String)] = []
        
        if let fileURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) {
            for url in fileURLs where url.pathExtension == "sqlite" {
                let filename = url.deletingPathExtension().lastPathComponent // "Bible_WEB"
                if filename.starts(with: "Bible_") {
                    let alias = filename.replacingOccurrences(of: "Bible_", with: "") // "WEB"
                    tempAttachedConfigs.append((path: url.path, alias: alias))
                }
            }
        }
        
        let attachedConfigs = tempAttachedConfigs
        
        // B. GRDB Configuration 설정 (ATTACH)
        var config = Configuration()
        config.prepareDatabase { [attachedConfigs] db in
            // 외부 성경 파일들 Attach
            for attachment in attachedConfigs {
                try db.execute(sql: "ATTACH DATABASE ? AS \(attachment.alias)", arguments: [attachment.path])
            }
        }
        
        // C. Pool 생성
        let pool = try DatabasePool(path: mainDatabaseURL.path, configuration: config)
        self.dbPool = pool
        
        // D. 마이그레이션 실행 (메인 DB 대상)
        // Attach된 DB는 읽기 전용이므로 마이그레이션 제외
        try migrator.migrate(pool)
        
        print("DatabasePool Reloaded. Attached: \(attachedConfigs.map { $0.alias })")
    }
    
//    init() throws {
//        let fileManager = FileManager.default
//        let dbUrl = try fileManager
//            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//            .appendingPathComponent("HagaBibleDB.sqlite")
//        
//        let savedVersion = UserDefaults.standard.string(forKey: dbVersionKey)
//        var shouldInitializeDB = false
//        
//        if savedVersion != currentDBVersion {
//            shouldInitializeDB = true
//            
//            if fileManager.fileExists(atPath: dbUrl.path) {
//                try? fileManager.removeItem(at: dbUrl)
//            }
//            
//            guard let bundleURL = Bundle.main.url(forResource: "BibleDB", withExtension: "sqlite") else {
//                throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "초기 DB 파일을 찾을 수 없습니다."])
//            }
//            try fileManager.copyItem(at: bundleURL, to: dbUrl)
//        }
//
//        dbPool = try DatabasePool(path: dbUrl.path)
//        
//        if shouldInitializeDB {
//            try migrator.migrate(dbPool)
//        }
//    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        return migrator
    }
}
