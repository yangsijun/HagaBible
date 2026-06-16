//
//  MockBibleFileRepository.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// No-op `BibleFileRepository` for SwiftUI previews and tests, so the version
/// store can be wired without touching ODR / the file system / the database.
final class MockBibleFileRepository: BibleFileRepository {
    private(set) var downloadedVersionCodes: [String] = []
    private(set) var deletedVersionCodes: [String] = []

    func downloadAndInstall(version: BibleVersion) async throws {
        downloadedVersionCodes.append(version.versionCode)
    }

    func delete(version: BibleVersion) async throws {
        deletedVersionCodes.append(version.versionCode)
    }
}
