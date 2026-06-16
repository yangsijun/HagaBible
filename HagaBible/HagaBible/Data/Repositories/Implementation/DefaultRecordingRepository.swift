//
//  DefaultRecordingRepository.swift
//  HagaBible
//
//  Created by 양시준 on 10/4/25.
//

import Foundation
import SwiftData

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

    public func updateRecording(_ recording: Recording) throws {
        try modelContext.save()
    }

    public func deleteRecording(_ recording: Recording) throws {
        modelContext.delete(recording)
        try modelContext.save()
    }
}
