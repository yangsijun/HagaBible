//
//  BibleRepository.swift
//  HagaBible
//
//  Created by 양시준 on 7/4/25.
//

protocol BibleRepository {
    func getAvailableVersions() async throws -> [BibleVersion]
    func getBibleContent(versionId: String) async throws -> BibleContent
    func getChapter(bookNum: Int, chapter: Int, versionId: String) async throws -> Chapter
    func downloadVersion(versionId: String, progress: @escaping (Double) -> Void) async throws
}
