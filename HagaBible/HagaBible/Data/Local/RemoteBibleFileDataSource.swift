//
//  RemoteBibleFileDataSource.swift
//  HagaBible
//
//  Downloads Bible_<versionCode>.sqlite from Supabase Storage. Two paths:
//  - Free, public-domain versions (KRV, WEB, WEBBE): direct download from the
//    PUBLIC bucket. Used as the fallback when On-Demand Resources is unavailable
//    (notably the "Designed for iPad" Mac runtime, where Apple's ODR CDN write
//    fails).
//  - Gated versions: never public. The app calls the `bible-version-url` Edge
//    Function, which returns a short-lived signed URL to the PRIVATE bucket only
//    when the caller passes the server-side gate:
//      • geo-restricted (KJV): the function checks the caller's country and
//        responds 403 for restricted regions (e.g. the UK for KJV);
//      • paid (NIV, NKRV): the app attaches its Apple-signed StoreKit
//        transaction (JWS); the function verifies the purchase and responds 402
//        if it can't confirm ownership.
//
//  Reuses the shared SupabaseClient (same one as cross-device sync).
//

import Foundation
import OSLog
import Supabase

actor RemoteBibleFileDataSource {
    private let client: SupabaseClient
    private let publicBucket: String
    private let gateFunction = "bible-version-url"
    /// Supplies the Apple-signed StoreKit transaction (JWS) for a paid version's
    /// `versionCode`, or `nil` if it isn't owned. Injected so this Data-layer
    /// type stays free of StoreKit/DI and is testable.
    private let entitlementProvider: @Sendable (String) async -> String?

    init(
        client: SupabaseClient,
        publicBucket: String = "bible-versions",
        entitlementProvider: @escaping @Sendable (String) async -> String? = { _ in nil }
    ) {
        self.client = client
        self.publicBucket = publicBucket
        self.entitlementProvider = entitlementProvider
    }

    /// Downloads the SQLite payload for a Bible version from Storage, routing
    /// gated versions (geo or purchase) through the server-side Edge Function.
    func download(versionCode: String) async throws -> Data {
        if BibleVersionDeliveryCatalog.usesPublicBucket(versionCode) {
            let path = BibleDatabaseService.fileName(for: versionCode)
            return try await client.storage.from(publicBucket).download(path: path)
        }
        return try await downloadGated(versionCode: versionCode)
    }

    private struct SignedURLResponse: Decodable { let url: String }

    /// Asks the Edge Function for a signed URL, passing whatever proof the gate
    /// needs (a StoreKit JWS for paid versions). Maps the gate's rejections to
    /// terminal, typed errors: 403 → region restricted, 402 → not purchased.
    private func downloadGated(versionCode: String) async throws -> Data {
        var body: [String: String] = ["code": versionCode]
        if BibleVersionDeliveryCatalog.requiresPurchaseVerification(versionCode) {
            guard let jws = await entitlementProvider(versionCode) else {
                // No on-device entitlement to present — don't even ask the server.
                Logger.repository.warning("No StoreKit entitlement to prove purchase of \(versionCode)")
                throw BibleDownloadError.notPurchased
            }
            body["transaction"] = jws
        }

        let signedURLString: String
        do {
            let response: SignedURLResponse = try await client.functions.invoke(
                gateFunction,
                options: .init(body: body)
            )
            signedURLString = response.url
        } catch let FunctionsError.httpError(code, _) {
            switch code {
            case 403:
                Logger.repository.warning("Geo gate denied \(versionCode) for this region")
                throw BibleDownloadError.regionRestricted
            case 402:
                Logger.repository.warning("Purchase gate could not verify ownership of \(versionCode)")
                throw BibleDownloadError.notPurchased
            default:
                throw BibleDownloadError.downloadFailed(statusCode: code)
            }
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
