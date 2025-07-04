//
//  BibleRepository.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

protocol BibleRepository {
    func getAvailableVersions() async throws -> [BibleVersion]
    func getBibleContent(versionId: String) async throws -> BibleContent
    func getChapter(book: Int, chapter: Int, versionId: String) async throws -> [Verse]
    func downloadVersion(versionId: String, progress: @escaping (Double) -> Void) async throws
}
