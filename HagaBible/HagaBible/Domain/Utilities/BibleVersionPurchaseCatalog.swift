//
//  BibleVersionPurchaseCatalog.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// Maps Bible `versionCode`s to their App Store product identifiers.
///
/// This is the single source of truth for *which* versions are paid. Any version
/// not listed in `paidProductIDs` is **free** (no purchase required).
///
/// Prices are intentionally NOT stored here — they are fetched live from the
/// store (`Product.displayPrice`), so prices can be changed in App Store Connect
/// without shipping an app update. To add a new paid version: register the
/// product in App Store Connect and add a `versionCode: productID` entry below.
///
/// Default classification (adjust to match your App Store Connect setup):
/// - Free (public domain): KJV, WEB, WEBBE, KRV (개역한글)
/// - Paid (copyright): NIV, NKRV (개역개정)
enum BibleVersionPurchaseCatalog {
    // Pure, immutable lookups over Sendable constant data. Marked `nonisolated` so they can be
    // read from any actor context (the module builds with default MainActor isolation, which would
    // otherwise pin these to the main actor and warn at Data-layer/non-isolated call sites).

    /// `versionCode` → App Store product identifier, for PAID versions only.
    nonisolated static let paidProductIDs: [String: String] = [
        "NIV": "dev.sijun.HagaBible.bible.niv",
        "NKRV": "dev.sijun.HagaBible.bible.nkrv",
    ]

    /// The product identifier for a paid version, or `nil` if the version is free.
    nonisolated static func productID(for versionCode: String) -> String? {
        paidProductIDs[versionCode]
    }

    /// Whether a version requires no purchase.
    nonisolated static func isFree(_ versionCode: String) -> Bool {
        paidProductIDs[versionCode] == nil
    }

    /// All product identifiers the app needs to query from the store.
    nonisolated static var allProductIDs: Set<String> {
        Set(paidProductIDs.values)
    }
}
