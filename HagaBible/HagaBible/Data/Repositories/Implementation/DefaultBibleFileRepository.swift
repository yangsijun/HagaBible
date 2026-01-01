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
    private let fileDataSource: FileSystemDataSource = DIContainer.shared.resolve(type: FileSystemDataSource.self)
    private let dbService: BibleDatabaseService = DIContainer.shared.resolve(type: BibleDatabaseService.self)

    private let maxRetryCount = 3

    func downloadAndInstall(version: BibleVersion) async throws {
        let tag = BibleDatabaseService.odrTag(for: version.versionCode)
        let resourceName = "Bible_\(version.versionCode)"
        let filename = BibleDatabaseService.fileName(for: version.versionCode)
        var lastError: Error?

        for attempt in 1...maxRetryCount {
            do {
                // 1. ODR 다운로드
                let tempURL = try await odrDataSource.fetchResource(tag: tag, resourceName: resourceName)

                // 2. 파일 이동
                _ = try fileDataSource.moveFileToDocuments(from: tempURL, filename: filename)

                // 3. ODR 리소스 해제
                await odrDataSource.releaseResource(tag: tag)

                // 4. 스키마 버전 저장
                dbService.saveODRSchemaVersion(for: version.versionCode)

                // 5. DB Pool 재로딩 (Attach 반영)
                try dbService.reloadDatabasePool()

                return // Success
            } catch {
                lastError = error
                // ODRDataSource.fetchResource already releases on failure
                Logger.repository.warning("Download attempt \(attempt)/\(self.maxRetryCount) failed for \(version.versionCode): \(error.localizedDescription)")

                if attempt < maxRetryCount {
                    // Wait before retry (exponential backoff)
                    try? await Task.sleep(for: .milliseconds(1000 * attempt))
                }
            }
        }

        throw lastError ?? URLError(.unknown)
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
