//
//  ODRDataSource.swift
//  HagaBible
//
//  Created by 양시준 on 11/29/25.
//

import Foundation
import OSLog

actor ODRDataSource {
    /// 메모리 해제 방지를 위한 요청 저장소
    private var activeRequests: [String: NSBundleResourceRequest] = [:]

    /// ODR 다운로드 실행
    /// - Parameters:
    ///   - tag: ODR 태그 이름 (예: Bible_KJV_2)
    ///   - resourceName: 실제 파일 이름 (확장자 제외, 예: Bible_KJV)
    func fetchResource(tag: String, resourceName: String) async throws -> URL {
        // 기존 요청이 있으면 먼저 해제
        if activeRequests[tag] != nil {
            releaseResource(tag: tag)
        }

        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        activeRequests[tag] = request

        // 이미 로컬에 있는지 확인
        let isAvailable = await withCheckedContinuation { continuation in
            request.conditionallyBeginAccessingResources { available in
                continuation.resume(returning: available)
            }
        }

        if isAvailable {
            Logger.repository.debug("ODR resource already available locally: \(tag)")
            return try getBundleURL(resourceName: resourceName)
        }

        Logger.repository.debug("Starting ODR download for tag: \(tag)")

        do {
            try await request.beginAccessingResources()
            Logger.repository.debug("ODR download completed for tag: \(tag)")
            return try getBundleURL(resourceName: resourceName)
        } catch {
            Logger.repository.error("ODR download failed for tag: \(tag), error: \(error.localizedDescription)")
            releaseResource(tag: tag)
            throw error
        }
    }

    /// 리소스 해제 (파일 복사 후 호출)
    func releaseResource(tag: String) {
        guard let request = activeRequests[tag] else { return }
        request.endAccessingResources()
        activeRequests[tag] = nil
        Logger.repository.debug("Released ODR resource for tag: \(tag)")
    }

    private func getBundleURL(resourceName: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "sqlite") else {
            throw URLError(.fileDoesNotExist)
        }
        return url
    }
}

// MARK: - File System Data Source
class FileSystemDataSource {
    private let fileManager = FileManager.default
    
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// ODR 파일을 Documents 폴더로 이동 (덮어쓰기 지원)
    func moveFileToDocuments(from srcURL: URL, filename: String) throws -> String {
        let destURL = documentsURL.appendingPathComponent(filename)
        
        // 기존 파일이 있다면 삭제 (Update 시나리오)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        
        let walURL = documentsURL.appendingPathComponent(filename + "-wal")
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }
        
        let shmURL = documentsURL.appendingPathComponent(filename + "-shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
        
        // 파일 복사 (ODR 원본은 읽기 전용이므로 copy 사용)
        try fileManager.copyItem(at: srcURL, to: destURL)
        return destURL.path
    }
    
    /// 파일 삭제
    func removeFile(filename: String) throws {
        let fileURL = documentsURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        let walURL = documentsURL.appendingPathComponent(filename + "-wal")
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }
        
        let shmURL = documentsURL.appendingPathComponent(filename + "-shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
    }
    
    /// 파일 존재 여부 확인
    func fileExists(filename: String) -> Bool {
        let fileURL = documentsURL.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// 현재 Documents에 있는 모든 성경 파일 경로 반환
    func getAllBibleFilePaths() -> [String: String] {
        // 반환형: [Alias: Path]
        var result: [String: String] = [:]
        
        guard let urls = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else {
            return result
        }
        
        // 파일명 규칙: "Bible_{ALIAS}.sqlite"
        for url in urls where url.pathExtension == "sqlite" && url.lastPathComponent.starts(with: "Bible_") {
            let filename = url.deletingPathExtension().lastPathComponent // "Bible_WEB"
            let alias = filename.replacingOccurrences(of: "Bible_", with: "") // "WEB"
            result[alias] = url.path
        }
        return result
    }
}
