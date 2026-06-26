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
                _ = try fileDataSource.moveFileToDocuments(from: tempURL, filename: filename)
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

    /// Supabase Storage path, with retry. A region restriction (HTTP 403 from the
    /// geo gate) is terminal and is NOT retried.
    private func downloadFromServer(_ version: BibleVersion) async throws {
        let code = version.versionCode
        let filename = BibleDatabaseService.fileName(for: code)
        var lastError: Error?

        for attempt in 1...maxRetryCount {
            do {
                let data = try await remoteDataSource.download(versionCode: code)
                _ = try fileDataSource.installFile(data: data, filename: filename)
                try finishInstall(code: code)
                return
            } catch BibleDownloadError.regionRestricted {
                throw BibleDownloadError.regionRestricted // hard block — do not retry
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

    /// Records the schema version and reloads the GRDB pool to ATTACH the file.
    private func finishInstall(code: String) throws {
        dbService.saveODRSchemaVersion(for: code)
        try dbService.reloadDatabasePool()
    }
    
    func delete(version: BibleVersion) async throws {
        // 1. 파일 삭제
        let filename = "Bible_\(version.versionCode).sqlite"
        try fileDataSource.removeFile(filename: filename)

        // 2. 스키마 버전 정보 삭제
        dbService.removeODRSchemaVersion(for: version.versionCode)

        // 3. DB Pool 재로딩 (Detach 반영)
        // 파일이 없어진 상태에서 Pool이 갱신되면 자동으로 Detach 상태가 됨
        try dbService.reloadDatabasePool()
    }
}
