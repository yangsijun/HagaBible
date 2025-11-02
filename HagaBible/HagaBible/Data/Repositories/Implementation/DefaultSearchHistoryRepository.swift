//
//  DefaultSearchHistoryRepository.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import Foundation
import SwiftData

@MainActor
class DefaultSearchHistoryRepository: SearchHistoryRepository {
    private let modelContext: ModelContext
    
    init() {
        let modelContainer = DIContainer.shared.resolve(type: ModelContainer.self)
        self.modelContext = modelContainer.mainContext
    }
    
    func fetchSearchHistories() throws -> [SearchHistory] {
        let searchHistories: [SearchHistory] = try modelContext.fetch(
            FetchDescriptor<SearchHistory>(
                predicate: nil,
                sortBy: [.init(\.createdAt, order: .reverse)]
            )
        )
        return searchHistories
    }
    
    func addSearchHistory(_ searchHistory: SearchHistory) throws {
        modelContext.insert(searchHistory)
        try modelContext.save()
    }
    
    func deleteSearchHistory(_ searchHistory: SearchHistory) throws {
        modelContext.delete(searchHistory)
        try modelContext.save()
    }
    
    func deleteAllSearchHistories() throws {
        try modelContext.delete(
            model: SearchHistory.self,
            where: #Predicate { _ in true }
        )
        try modelContext.save()
    }
    
    
}
