//
//  SearchHistoryRepository.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

protocol SearchHistoryRepository {
    func fetchSearchHistories() throws -> [SearchHistory]
    func addSearchHistory(_ searchHistory: SearchHistory) throws
    func deleteSearchHistory(_ searchHistory: SearchHistory) throws
    func deleteAllSearchHistories() throws
}
