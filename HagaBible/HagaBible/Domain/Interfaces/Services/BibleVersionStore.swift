//
//  BibleVersionStore.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

import Foundation

/// Notification posted when the set of owned entitlements may have changed
/// (e.g. a `Transaction.updates` arrival from an Ask-to-Buy approval or a
/// purchase made on another device). Observers should re-query the store.
extension Notification.Name {
    nonisolated static let bibleVersionEntitlementsChanged = Notification.Name("bibleVersionEntitlementsChanged")
}

/// Abstraction over the platform in-app purchase store (StoreKit), keeping the
/// Domain layer free of StoreKit types. Concrete implementation lives in Data.
protocol BibleVersionStore: Sendable {
    /// Fetch product metadata (incl. live localized price) for the given identifiers.
    func products(for productIDs: Set<String>) async throws -> [StoreProduct]

    /// The set of product identifiers the user currently owns, verified by the
    /// platform (StoreKit's `Transaction.currentEntitlements`).
    func purchasedProductIDs() async -> Set<String>

    /// Begin a purchase for the given product identifier.
    func purchase(productID: String) async throws -> PurchaseResult

    /// The Apple-signed transaction (JWS representation) for the user's current
    /// entitlement to `productID`, or `nil` if the version isn't owned. Sent to
    /// the download Edge Function so it can verify the purchase server-side
    /// before issuing a signed URL for a paid version.
    func entitlementJWS(for productID: String) async -> String?

    /// Restore/sync entitlements from the App Store (`AppStore.sync()`).
    func restore() async throws
}
