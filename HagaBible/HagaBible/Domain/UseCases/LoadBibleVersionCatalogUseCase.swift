//
//  LoadBibleVersionCatalogUseCase.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// Builds the version-management catalog by merging:
/// - the available versions and their download state (`BibleRepository`)
/// - the purchase classification (`BibleVersionPurchaseCatalog`)
/// - live prices and owned entitlements (`BibleVersionStore`)
protocol LoadBibleVersionCatalogUseCase: Sendable {
    func execute() async -> [BibleVersionItem]
}

final class DefaultLoadBibleVersionCatalogUseCase: LoadBibleVersionCatalogUseCase {
    private let bibleRepository: BibleRepository
    private let store: BibleVersionStore

    init(bibleRepository: BibleRepository, store: BibleVersionStore) {
        self.bibleRepository = bibleRepository
        self.store = store
    }

    func execute() async -> [BibleVersionItem] {
        let versions = (try? await bibleRepository.fetchBibleVersionList()) ?? []

        // Fetch prices and entitlements concurrently; degrade gracefully on failure.
        async let ownedTask = store.purchasedProductIDs()
        let products = (try? await store.products(for: BibleVersionPurchaseCatalog.allProductIDs)) ?? []
        let owned = await ownedTask

        let priceByProductID = Dictionary(
            products.map { ($0.id, $0.displayPrice) },
            uniquingKeysWith: { first, _ in first }
        )

        return versions.map { version in
            let availability: BibleVersionItem.Availability
            if let productID = BibleVersionPurchaseCatalog.productID(for: version.versionCode) {
                if owned.contains(productID) {
                    availability = .purchased
                } else {
                    availability = .locked(displayPrice: priceByProductID[productID] ?? "")
                }
            } else {
                availability = .free
            }
            return BibleVersionItem(version: version, availability: availability)
        }
    }
}
