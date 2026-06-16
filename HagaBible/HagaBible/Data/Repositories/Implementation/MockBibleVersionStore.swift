//
//  MockBibleVersionStore.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

import Foundation

/// In-memory `BibleVersionStore` for SwiftUI previews and unit tests.
///
/// Configurable so tests can drive each acquisition path (free, locked,
/// purchased, cancelled, pending) without hitting StoreKit.
final class MockBibleVersionStore: BibleVersionStore, @unchecked Sendable {
    /// Products the store "knows about", keyed by product identifier.
    var availableProducts: [StoreProduct]
    /// Product identifiers the user already owns.
    var ownedProductIDs: Set<String>
    /// Result returned by the next `purchase(productID:)` call.
    var nextPurchaseResult: PurchaseResult
    /// Error thrown by `purchase` / `restore`, if set.
    var purchaseError: Error?

    /// Records of calls, for test assertions.
    private(set) var purchaseCallProductIDs: [String] = []
    private(set) var restoreCallCount = 0

    init(
        availableProducts: [StoreProduct] = [
            StoreProduct(id: "dev.sijun.HagaBible.bible.niv", displayName: "New International Version", displayPrice: "$2.99"),
            StoreProduct(id: "dev.sijun.HagaBible.bible.nkrv", displayName: "개역개정", displayPrice: "₩3,900"),
        ],
        ownedProductIDs: Set<String> = [],
        nextPurchaseResult: PurchaseResult = .success
    ) {
        self.availableProducts = availableProducts
        self.ownedProductIDs = ownedProductIDs
        self.nextPurchaseResult = nextPurchaseResult
    }

    func products(for productIDs: Set<String>) async throws -> [StoreProduct] {
        availableProducts.filter { productIDs.contains($0.id) }
    }

    func purchasedProductIDs() async -> Set<String> {
        ownedProductIDs
    }

    func purchase(productID: String) async throws -> PurchaseResult {
        purchaseCallProductIDs.append(productID)
        if let purchaseError { throw purchaseError }
        if nextPurchaseResult == .success {
            ownedProductIDs.insert(productID)
        }
        return nextPurchaseResult
    }

    func restore() async throws {
        restoreCallCount += 1
        if let purchaseError { throw purchaseError }
    }
}
