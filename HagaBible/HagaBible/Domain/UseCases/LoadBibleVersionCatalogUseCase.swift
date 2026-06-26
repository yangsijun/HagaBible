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
    private let regionService: RegionService

    init(bibleRepository: BibleRepository, store: BibleVersionStore, regionService: RegionService = RegionService()) {
        self.bibleRepository = bibleRepository
        self.store = store
        self.regionService = regionService
    }

    func execute() async -> [BibleVersionItem] {
        var versions = (try? await bibleRepository.fetchBibleVersionList()) ?? []

        // Client-side geo gate (UX only; the server is authoritative): hide a
        // geo-restricted, not-yet-downloaded version when the current region is
        // blocked, so the user isn't offered a download the server will refuse.
        // Already-downloaded versions stay listed so they remain manageable.
        let here = await regionService.currentRegionCandidates()
        if !here.isEmpty {
            versions = versions.filter { version in
                let restricted = BibleVersionDeliveryCatalog.restrictedRegions(for: version.versionCode)
                guard !restricted.isEmpty, !version.isDownloaded else { return true }
                return here.isDisjoint(with: restricted)
            }
        }

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
