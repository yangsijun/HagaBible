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
    /// `versionCode` → App Store product identifier, for PAID versions only.
    static let paidProductIDs: [String: String] = [
        "NIV": "dev.sijun.HagaBible.bible.niv",
        "NKRV": "dev.sijun.HagaBible.bible.nkrv",
    ]

    /// The product identifier for a paid version, or `nil` if the version is free.
    static func productID(for versionCode: String) -> String? {
        paidProductIDs[versionCode]
    }

    /// Whether a version requires no purchase.
    static func isFree(_ versionCode: String) -> Bool {
        paidProductIDs[versionCode] == nil
    }

    /// All product identifiers the app needs to query from the store.
    static var allProductIDs: Set<String> {
        Set(paidProductIDs.values)
    }
}
