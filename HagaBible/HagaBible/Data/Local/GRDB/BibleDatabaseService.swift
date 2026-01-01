//
//  BibleDatabaseService.swift
//  HagaBible
//
//  Created by 양시준 on 7/11/25.
//

import Foundation
import GRDB
import OSLog

final class BibleDatabaseService {
    private(set) var dbPool: DatabasePool?
    
    private let lock = NSLock()
    
    private let dbVersionKey = "dbVersion"
    private let currentDBVersion = "1.5"

    // ODR Bible file schema version - increment when Bible_*.sqlite schema changes
    static let odrSchemaVersion = "1.1"
    private let odrSchemaVersionKeyPrefix = "odrSchemaVersion_"
    
    private var mainDatabaseURL: URL {
        try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HagaBibleDB.sqlite")
    }

    init() throws {
        do {
            try setupMainDatabaseFile() // 1. 메인 파일 준비
            try reloadDatabasePool()    // 2. Pool 연결 (Attach 포함)
            try validateDatabase()      // 3. DB 무결성 검사
        } catch {
            // DB 손상 시 재설치 시도
            Logger.database.error("Database initialisation error: \(error.localizedDescription). Attempting recovery...")
            dbPool = nil  // 기존 연결 해제
            // WAL, SHM 파일도 함께 삭제 (HagaBibleDB.sqlite-wal, HagaBibleDB.sqlite-shm)
            let dbPath = mainDatabaseURL.path
            try? FileManager.default.removeItem(atPath: dbPath)
            try? FileManager.default.removeItem(atPath: dbPath + "-wal")
            try? FileManager.default.removeItem(atPath: dbPath + "-shm")
            UserDefaults.standard.removeObject(forKey: dbVersionKey)
            try setupMainDatabaseFile()
            try reloadDatabasePool()
            try validateDatabase()
            Logger.database.info("Database recovery successful")
        }
    }

    /// DB 무결성 검사 - 손상된 DB 조기 감지
    private func validateDatabase() throws {
        guard let pool = dbPool else {
            throw NSError(domain: "DatabaseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database pool is nil"])
        }
        // 간단한 쿼리로 DB 무결성 확인
        _ = try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM bible_version")
        }
    }
    
    // MARK: - 1. 메인 DB 파일 준비 (기존 로직 유지)
    /// 번들에서 초기 DB 파일을 복사하거나 버전을 체크하여 업데이트합니다.
    private func setupMainDatabaseFile() throws {
        let fileManager = FileManager.default
        let dbUrl = mainDatabaseURL

        let savedVersion = UserDefaults.standard.string(forKey: dbVersionKey)
        var shouldReplaceDB = false

        Logger.database.debug("Saved version: \(savedVersion ?? "nil", privacy: .public), current version: \(self.currentDBVersion)")
        Logger.database.debug("DB path: \(dbUrl.path, privacy: .public)")
        Logger.database.debug("File exists: \(fileManager.fileExists(atPath: dbUrl.path))")

        // 버전이 다르면 교체 플래그 설정
        if savedVersion != currentDBVersion {
            shouldReplaceDB = true
        }

        // 파일이 아예 없어도 복사해야 함
        if !fileManager.fileExists(atPath: dbUrl.path) {
            shouldReplaceDB = true
        }

        if shouldReplaceDB {
            Logger.database.info("Replacing database...")

            // 기존 파일 제거 (WAL, SHM 포함)
            let dbPath = dbUrl.path
            if fileManager.fileExists(atPath: dbPath) {
                try? fileManager.removeItem(atPath: dbPath)
                try? fileManager.removeItem(atPath: dbPath + "-wal")
                try? fileManager.removeItem(atPath: dbPath + "-shm")
                Logger.database.debug("Removed existing file and WAL/SHM")
            }

            // 번들에서 복사
            guard let bundleURL = Bundle.main.url(forResource: "BibleDB", withExtension: "sqlite") else {
                throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundle에서 초기 BibleDB.sqlite를 찾을 수 없습니다."])
            }

            let bundleFileSize = (try? fileManager.attributesOfItem(atPath: bundleURL.path)[.size] as? Int) ?? 0
            Logger.database.debug("Bundle file size: \(bundleFileSize) bytes")

            try fileManager.copyItem(at: bundleURL, to: dbUrl)

            let copiedFileSize = (try? fileManager.attributesOfItem(atPath: dbUrl.path)[.size] as? Int) ?? 0
            Logger.database.debug("Copied file size: \(copiedFileSize) bytes")

            // 버전 갱신 저장
            UserDefaults.standard.set(currentDBVersion, forKey: dbVersionKey)
            Logger.database.info("Database version updated to \(self.currentDBVersion)")
        } else {
            Logger.database.debug("Using existing database file")
        }
    }
    
    // MARK: - 2. Pool 재로딩 (ODR Attach 통합 핵심 로직)
    /// 다운로드된 성경 파일들을 스캔하여 DB Pool을 재설정합니다.
    func reloadDatabasePool() throws {
        lock.lock()
        defer { lock.unlock() }

        // 기존 연결 해제
        dbPool = nil

        // 스키마 버전이 맞지 않는 파일 삭제
        removeOutdatedBibleFiles()

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
        
        Logger.database.info("Database pool reloaded. Attached: \(attachedConfigs.map { $0.alias })")
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        return migrator
    }

    // MARK: - ODR Schema Version Management

    /// Saves the current ODR schema version for a downloaded Bible file
    func saveODRSchemaVersion(for versionCode: String) {
        let key = odrSchemaVersionKeyPrefix + versionCode
        UserDefaults.standard.set(Self.odrSchemaVersion, forKey: key)
    }

    /// Removes the stored ODR schema version for a Bible file
    func removeODRSchemaVersion(for versionCode: String) {
        let key = odrSchemaVersionKeyPrefix + versionCode
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Checks and removes outdated Bible files that don't match the current schema version
    private func removeOutdatedBibleFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        guard let fileURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else {
            return
        }

        for url in fileURLs where url.pathExtension == "sqlite" {
            let filename = url.deletingPathExtension().lastPathComponent
            if filename.starts(with: "Bible_") {
                let versionCode = filename.replacingOccurrences(of: "Bible_", with: "")
                let key = odrSchemaVersionKeyPrefix + versionCode
                let savedVersion = UserDefaults.standard.string(forKey: key)

                // If no version stored or version mismatch, delete the file
                if savedVersion != Self.odrSchemaVersion {
                    try? fileManager.removeItem(at: url)
                    UserDefaults.standard.removeObject(forKey: key)
                    Logger.database.info("Removed outdated Bible file: \(filename) (stored: \(savedVersion ?? "none"), current: \(Self.odrSchemaVersion))")
                }
            }
        }
    }
}
