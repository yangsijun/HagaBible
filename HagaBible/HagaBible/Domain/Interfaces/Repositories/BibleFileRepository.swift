//
//  BibleFileRepository.swift
//  HagaBible
//
//  Created by 양시준 on 11/29/25.
//

protocol BibleFileRepository {
    func downloadAndInstall(version: BibleVersion) async throws
    func delete(version: BibleVersion) async throws
}
