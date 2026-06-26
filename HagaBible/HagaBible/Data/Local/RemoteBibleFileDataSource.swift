//
//  RemoteBibleFileDataSource.swift
//  HagaBible
//
//  Downloads Bible_<versionCode>.sqlite from Supabase Storage. Two paths:
//  - Unrestricted versions: direct download from the PUBLIC bucket. Used as the
//    fallback when On-Demand Resources is unavailable (notably the "Designed for
//    iPad" Mac runtime, where Apple's ODR CDN write fails).
//  - Geo-restricted versions (KJV): never public. The app calls the
//    `bible-version-url` Edge Function, which checks the caller's country
//    server-side, returns a short-lived signed URL for allowed regions, and
//    responds 403 for restricted regions (e.g. the UK for KJV).
//
//  Reuses the shared SupabaseClient (same one as cross-device sync).
//

import Foundation
import OSLog
import Supabase

actor RemoteBibleFileDataSource {
    private let client: SupabaseClient
    private let publicBucket: String
    private let geoGateFunction = "bible-version-url"

    init(client: SupabaseClient, publicBucket: String = "bible-versions") {
        self.client = client
        self.publicBucket = publicBucket
    }

    /// Downloads the SQLite payload for a Bible version from Storage, routing
    /// geo-restricted versions through the server-side geo gate.
    func download(versionCode: String) async throws -> Data {
        if BibleVersionDeliveryCatalog.isGeoRestricted(versionCode) {
            return try await downloadGeoGated(versionCode: versionCode)
        }
        let path = BibleDatabaseService.fileName(for: versionCode)
        return try await client.storage.from(publicBucket).download(path: path)
    }

    private struct SignedURLResponse: Decodable { let url: String }

    /// Asks the Edge Function for a signed URL (allowed region) or a 403
    /// (restricted region), then downloads the bytes from the signed URL.
    private func downloadGeoGated(versionCode: String) async throws -> Data {
        let signedURLString: String
        do {
            let response: SignedURLResponse = try await client.functions.invoke(
                geoGateFunction,
                options: .init(body: ["code": versionCode])
            )
            signedURLString = response.url
        } catch let FunctionsError.httpError(code, _) where code == 403 {
            Logger.repository.warning("Geo gate denied \(versionCode) for this region")
            throw BibleDownloadError.regionRestricted
        }

        guard let url = URL(string: signedURLString) else {
            throw BibleDownloadError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw BibleDownloadError.downloadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}
