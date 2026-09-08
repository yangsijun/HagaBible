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
    private let currentDBVersion = "1.6"

    // Per-version content versions live in BibleVersionDeliveryCatalog.contentVersions:
    // bump the entry for the Bible_*.sqlite that changed (plus its pbxproj ASSET_TAGS).
    // The UserDefaults key prefix is historical ("odrSchemaVersion_") and must stay as is —
    // installed devices already hold their per-version values under it.
    private let contentVersionKeyPrefix = "odrSchemaVersion_"

    /// ODR 태그 생성 (예: Bible_NKRV_3): 파일 이름 + 그 역본의 콘텐츠 버전.
    static func odrTag(for versionCode: String) -> String {
        return "Bible_\(versionCode)_\(BibleVersionDeliveryCatalog.contentVersion(for: versionCode))"
    }

    /// ODR 태그에서 파일 이름 추출 (예: Bible_KJV.sqlite)
    /// `nonisolated`: a pure string map, read from the non-isolated Data layer
    /// (`RemoteBibleFileDataSource`) under the module's default MainActor isolation.
    nonisolated static func fileName(for versionCode: String) -> String {
        return "Bible_\(versionCode).sqlite"
    }

    /// Installed Bible files whose recorded content version differs from the one this
    /// build ships for that version (`BibleVersionDeliveryCatalog.contentVersions`).
    ///
    /// They stay on disk and ATTACHed — the user keeps reading the old text — while
    /// `RootView` re-downloads them in the background; the install replaces the file and
    /// reloads the pool, after which the code drops out of this list. Deleting up front
    /// (the previous behaviour) left the reader blank whenever the download failed.
    /// This relies on a content bump never changing the attached file's schema; a bump
    /// that does needs a separate compatibility check before the old file is attached.
    private(set) var outdatedVersionCodes: [String] = []
    
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
        closeCurrentPool()

        // 콘텐츠 버전이 맞지 않는 파일은 삭제하지 않고 기록만 남긴다 (백그라운드 재다운로드 대상).
        collectOutdatedBibleFiles()

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
        //
        // Reader connections ATTACH here. The writer must NOT: `DatabasePool.init` runs an
        // unqualified `PRAGMA journal_mode = WAL` on the writer right after this hook, and
        // SQLite applies an unqualified journal_mode to every attached database. That flips
        // the header of each Bible file to WAL without creating its `-wal`/`-shm`, and a
        // read-only connection cannot open such a file (SQLITE_CANTOPEN 14 on ATTACH) — the
        // reader went blank after a background content update. Attaching the writer after
        // init keeps the Bible files in their shipped rollback-journal mode, untouched.
        var config = Configuration()
        config.prepareDatabase { [attachedConfigs] db in
            guard db.configuration.readonly else { return }
            try Self.attachBibleFiles(attachedConfigs, to: db)
        }
        
        // C. Pool 생성 (+ writer ATTACH, WAL 전환 이후)
        let pool = try DatabasePool(path: mainDatabaseURL.path, configuration: config)
        try pool.writeWithoutTransaction { db in
            try Self.attachBibleFiles(attachedConfigs, to: db)
            // Earlier builds attached the writer before the WAL pragma, so files installed by
            // them carry a WAL header. Put those back once; readers then never depend on
            // `-wal`/`-shm` side files that vanish whenever the last connection closes.
            for attachment in attachedConfigs {
                let mode = try String.fetchOne(db, sql: "PRAGMA \(attachment.alias).journal_mode")
                if mode?.lowercased() == "wal" {
                    _ = try String.fetchOne(db, sql: "PRAGMA \(attachment.alias).journal_mode = DELETE")
                    Logger.database.info("Restored rollback journal mode for \(attachment.alias, privacy: .public)")
                }
            }
        }
        self.dbPool = pool
        
        // D. 마이그레이션 실행 (메인 DB 대상)
        // Attach된 DB는 읽기 전용이므로 마이그레이션 제외
        try migrator.migrate(pool)
        
        Logger.database.info("Database pool reloaded. Attached: \(attachedConfigs.map { $0.alias })")
    }

    private static func attachBibleFiles(_ attachments: [(path: String, alias: String)], to db: Database) throws {
        for attachment in attachments {
            try db.execute(sql: "ATTACH DATABASE ? AS \(attachment.alias)", arguments: [attachment.path])
        }
    }

    /// Closes every connection so a `Bible_*.sqlite` can be replaced or deleted.
    ///
    /// Apple's libsqlite3 treats a database file that is unlinked while a connection
    /// still has it open as an API violation ("BUG IN CLIENT OF libsqlite3.dylib:
    /// vnode unlinked while in use") and invalidates the open file descriptors, so the
    /// swap must happen with the pool closed, followed by `reloadDatabasePool()`.
    /// `close()` waits for in-flight reads/writes to finish.
    func closeDatabasePool() {
        lock.lock()
        defer { lock.unlock() }
        closeCurrentPool()
    }

    private func closeCurrentPool() {
        if let pool = dbPool {
            do {
                try pool.close()
            } catch {
                Logger.database.error("Failed to close database pool cleanly: \(error.localizedDescription)")
            }
        }
        dbPool = nil
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif

        return migrator
    }

    // MARK: - Installed Content Version Management

    /// Records which content version of `versionCode` was just installed.
    func saveInstalledContentVersion(for versionCode: String) {
        let key = contentVersionKeyPrefix + versionCode
        UserDefaults.standard.set(BibleVersionDeliveryCatalog.contentVersion(for: versionCode), forKey: key)
    }

    /// Forgets the installed content version of `versionCode` (file deleted).
    func removeInstalledContentVersion(for versionCode: String) {
        let key = contentVersionKeyPrefix + versionCode
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Compares each installed Bible file's recorded content version with the one this
    /// build ships and records the mismatches in `outdatedVersionCodes`. Each version is
    /// checked on its own, so bumping one version's content never touches the others.
    private func collectOutdatedBibleFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        guard let fileURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else {
            outdatedVersionCodes = []
            return
        }

        var installedCodes: [String] = []
        var savedVersions: [String: String] = [:]
        for url in fileURLs where url.pathExtension == "sqlite" {
            let filename = url.deletingPathExtension().lastPathComponent
            guard filename.starts(with: "Bible_") else { continue }
            let versionCode = filename.replacingOccurrences(of: "Bible_", with: "")
            installedCodes.append(versionCode)
            if let saved = UserDefaults.standard.string(forKey: contentVersionKeyPrefix + versionCode) {
                savedVersions[versionCode] = saved
            }
        }

        outdatedVersionCodes = Self.outdatedVersionCodes(installed: installedCodes, savedVersions: savedVersions)
        for versionCode in outdatedVersionCodes {
            Logger.database.info("Bible file for \(versionCode) is outdated (stored: \(savedVersions[versionCode] ?? "none"), current: \(BibleVersionDeliveryCatalog.contentVersion(for: versionCode))); keeping it until the update lands")
        }
    }

    /// The installed version codes whose saved content version is missing or differs
    /// from the catalog's current one. Pure so it can be unit-tested.
    nonisolated static func outdatedVersionCodes(installed: [String], savedVersions: [String: String]) -> [String] {
        installed.filter { code in
            savedVersions[code] != BibleVersionDeliveryCatalog.contentVersion(for: code)
        }
    }
}
