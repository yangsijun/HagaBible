//
//  DefaultBibleFileRepository.swift
//  HagaBible
//
//  Created by 양시준 on 11/29/25.
//

import Foundation
import OSLog

class DefaultBibleFileRepository: BibleFileRepository {
    private let odrDataSource: ODRDataSource = DIContainer.shared.resolve(type: ODRDataSource.self)
    private let remoteDataSource: RemoteBibleFileDataSource = DIContainer.shared.resolve(type: RemoteBibleFileDataSource.self)
    private let fileDataSource: FileSystemDataSource = DIContainer.shared.resolve(type: FileSystemDataSource.self)
    private let dbService: BibleDatabaseService = DIContainer.shared.resolve(type: BibleDatabaseService.self)

    private let maxRetryCount = 3

    func downloadAndInstall(version: BibleVersion) async throws {
        let code = version.versionCode

        // Geo-restricted versions (KJV) never ship via ODR — ODR has no per-asset
        // territory control — so they download Supabase-only through the
        // server-side geo gate, which blocks restricted regions (e.g. UK).
        if BibleVersionDeliveryCatalog.isGeoRestricted(code) {
            try await downloadFromServer(version)
            return
        }

        // Everything else: ODR is primary, Supabase Storage is the fallback (ODR
        // is unavailable on the "Designed for iPad" Mac runtime).
        do {
            try await downloadFromODR(version)
        } catch {
            Logger.repository.warning("ODR failed for \(code), falling back to Supabase: \(error.localizedDescription)")
            try await downloadFromServer(version)
        }
    }

    /// On-Demand Resources path (Apple CDN / embedded asset packs), with retry.
    private func downloadFromODR(_ version: BibleVersion) async throws {
        let code = version.versionCode
        let tag = BibleDatabaseService.odrTag(for: code)
        let resourceName = "Bible_\(code)"
        let filename = BibleDatabaseService.fileName(for: code)
        var lastError: Error?

        for attempt in 1...maxRetryCount {
            do {
                let tempURL = try await odrDataSource.fetchResource(tag: tag, resourceName: resourceName)
                do {
                    try replaceFileWithPoolClosed {
                        _ = try fileDataSource.moveFileToDocuments(from: tempURL, filename: filename)
                    }
                } catch {
                    await odrDataSource.releaseResource(tag: tag)
                    throw error
                }
                await odrDataSource.releaseResource(tag: tag)
                try finishInstall(code: code)
                return
            } catch {
                lastError = error
                // ODRDataSource.fetchResource already releases on failure
                Logger.repository.warning("ODR attempt \(attempt)/\(self.maxRetryCount) failed for \(code): \(error.localizedDescription)")
                if attempt < maxRetryCount {
                    try? await Task.sleep(for: .milliseconds(1000 * attempt))
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Supabase Storage path, with retry. Server-side gate rejections — a region
    /// restriction (HTTP 403) or an unverified purchase (HTTP 402) — are terminal
    /// and are NOT retried.
    private func downloadFromServer(_ version: BibleVersion) async throws {
        let code = version.versionCode
        let filename = BibleDatabaseService.fileName(for: code)
        var lastError: Error?

        for attempt in 1...maxRetryCount {
            do {
                let data = try await remoteDataSource.download(versionCode: code)
                try replaceFileWithPoolClosed {
                    _ = try fileDataSource.installFile(data: data, filename: filename)
                }
                try finishInstall(code: code)
                return
            } catch BibleDownloadError.regionRestricted {
                throw BibleDownloadError.regionRestricted // hard block — do not retry
            } catch BibleDownloadError.notPurchased {
                throw BibleDownloadError.notPurchased // hard block — do not retry
            } catch {
                lastError = error
                Logger.repository.warning("Supabase attempt \(attempt)/\(self.maxRetryCount) failed for \(code): \(error.localizedDescription)")
                if attempt < maxRetryCount {
                    try? await Task.sleep(for: .milliseconds(1000 * attempt))
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Runs `swap` — which deletes or replaces a `Bible_*.sqlite` — with every GRDB
    /// connection closed. The file may currently be ATTACHed (a content update replaces
    /// the version the user is reading), and unlinking an open database makes Apple's
    /// SQLite invalidate the connection and refuse the path afterwards (see
    /// `BibleDatabaseService.closeDatabasePool`). The pool is reopened by the caller's
    /// `reloadDatabasePool()`; if `swap` throws it is reopened here so reads resume.
    private func replaceFileWithPoolClosed(_ swap: () throws -> Void) throws {
        dbService.closeDatabasePool()
        do {
            try swap()
        } catch {
            try? dbService.reloadDatabasePool()
            throw error
        }
    }

    /// Records the installed content version and reloads the GRDB pool to ATTACH the file.
    private func finishInstall(code: String) throws {
        dbService.saveInstalledContentVersion(for: code)
        try dbService.reloadDatabasePool()
    }
    
    func delete(version: BibleVersion) async throws {
        // 1. 파일 삭제 (풀을 닫은 상태에서 — 열린 DB 파일을 지우면 SQLite가 커넥션을 무효화함)
        let filename = "Bible_\(version.versionCode).sqlite"
        try replaceFileWithPoolClosed {
            try fileDataSource.removeFile(filename: filename)
        }

        // 2. 설치된 콘텐츠 버전 정보 삭제
        dbService.removeInstalledContentVersion(for: version.versionCode)

        // 3. DB Pool 재로딩 (Detach 반영)
        // 파일이 없어진 상태에서 Pool이 갱신되면 자동으로 Detach 상태가 됨
        try dbService.reloadDatabasePool()
    }
}
