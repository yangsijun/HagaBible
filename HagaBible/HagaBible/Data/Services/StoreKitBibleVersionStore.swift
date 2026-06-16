//
//  StoreKitBibleVersionStore.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

import Foundation
import OSLog
import StoreKit

/// StoreKit 2 implementation of `BibleVersionStore`.
///
/// Entitlements are verified on-device via `Transaction.currentEntitlements`
/// (Apple-signed, no backend required). A long-lived listener handles
/// `Transaction.updates` (Ask-to-Buy approvals, cross-device purchases) by
/// finishing the transaction and broadcasting `.bibleVersionEntitlementsChanged`.
final class StoreKitBibleVersionStore: BibleVersionStore {
    private let updatesListener: Task<Void, Never>

    init() {
        // A main-actor Task is sufficient: `Transaction.updates` suspends between
        // events rather than busy-looping, and posting on the main actor keeps the
        // SwiftUI observer hop-free.
        updatesListener = Task {
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                NotificationCenter.default.post(name: .bibleVersionEntitlementsChanged, object: nil)
                Logger.repository.debug("StoreKit transaction update finished for \(transaction.productID)")
            }
        }
    }

    deinit {
        updatesListener.cancel()
    }

    // MARK: - BibleVersionStore

    func products(for productIDs: Set<String>) async throws -> [StoreProduct] {
        guard !productIDs.isEmpty else { return [] }
        do {
            let products = try await Product.products(for: productIDs)
            // Diagnostic: empty result means the active store (StoreKit test session
            // in dev, App Store in prod) could not resolve these IDs. Logs the
            // requested vs. resolved IDs so a 0-count is immediately explainable.
            Logger.repository.info(
                "StoreKit products(for:) requested \(productIDs.sorted(), privacy: .public) → resolved \(products.count) \(products.map(\.id).sorted(), privacy: .public)"
            )
            return products.map {
                StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
        } catch {
            Logger.repository.error(
                "StoreKit products(for:) FAILED for \(productIDs.sorted(), privacy: .public): \(error, privacy: .public)"
            )
            throw error
        }
    }

    func purchasedProductIDs() async -> Set<String> {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Skip revoked (refunded) entitlements.
            if transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        return owned
    }

    func purchase(productID: String) async throws -> PurchaseResult {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            NotificationCenter.default.post(name: .bibleVersionEntitlementsChanged, object: nil)
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        NotificationCenter.default.post(name: .bibleVersionEntitlementsChanged, object: nil)
    }

    // MARK: - Helpers

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
