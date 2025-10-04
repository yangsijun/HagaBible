//
//  RecordingRepository.swift
//  HagaBible
//
//  Created by 양시준 on 9/3/25.
//

protocol RecordingRepository {
    func fetchRecordings() throws -> [Recording]
    func addRecording(_ recording: Recording) throws
    func deleteRecording(_ recording: Recording) throws
}
