//
//  RecordingRepository.swift
//  HagaBible
//
//  Created by 양시준 on 9/3/25.
//

import SwiftData
import SwiftUI

protocol RecordingRepository {
    func fetchRecordings() throws -> [Recording]
    func addRecording(_ recording: Recording) throws
    func deleteRecording(_ recording: Recording) throws
}

@MainActor
class DefaultRecordingRepository: RecordingRepository {
    private let modelContext: ModelContext

    init() {
        let modelContainer = DIContainer.shared.resolve(type: ModelContainer.self)
        self.modelContext = modelContainer.mainContext
    }
    
    public func fetchRecordings() throws -> [Recording] {
        let recordings = try modelContext.fetch(
            FetchDescriptor<Recording>(
                predicate: nil,
                sortBy: [.init(\.createdAt, order: .reverse)]
            )
        )
        return recordings
    }

    public func addRecording(_ recording: Recording) throws {
        modelContext.insert(recording)
        try modelContext.save()
    }

    public func deleteRecording(_ recording: Recording) throws {
        modelContext.delete(recording)
        try modelContext.save()
    }
}
