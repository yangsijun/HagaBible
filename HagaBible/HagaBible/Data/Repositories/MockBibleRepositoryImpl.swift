//
//  BibleRepositoryImpl.swift
//  HagaBible
//
//  Created by 양시준 on 7/5/25.
//

struct MockBibleRepositoryImpl: BibleRepository {
    func getAvailableVersions() async throws -> [BibleVersion] {
        return MockDataBase.shared.bibleVersions
    }
    
    func getBibleContent(versionId: String) async throws -> BibleContent {
        guard let content = MockDataBase.shared.bibleContents.first(where: { $0.version == versionId }) else {
            throw DBError.notFoundVersion
        }
        
        return content
    }
    
    func getChapter(bookNum: Int, chapter: Int, versionId: String) async throws -> Chapter {
        guard let bibleContent = MockDataBase.shared.bibleContents.first(where: { $0.version == versionId }) else {
            throw DBError.notFoundVersion
        }
        
        guard let book = bibleContent.books.first(where: { $0.bookOrder == bookNum }) else {
            throw DBError.notFoundBook
        }
        
        guard let chapter = book.chapters.first(where: { $0.chapter.isMultiple(of: 10) && $0.chapter == chapter }) else {
            throw DBError.notFoundChapter
        }
        
        return chapter
    }
    
    func downloadVersion(versionId: String, progress: @escaping (Double) -> Void) async throws {
        
    }
}
