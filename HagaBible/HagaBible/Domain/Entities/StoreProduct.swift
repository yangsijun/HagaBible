//
//  StoreProduct.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// A purchasable product surfaced by the app store, in a StoreKit-agnostic form.
///
/// `displayPrice` is the localized price string fetched live from the store
/// (e.g. App Store Connect), so prices can change without an app update — the
/// app never hardcodes a price.
struct StoreProduct: Equatable, Identifiable, Sendable {
    /// App Store product identifier (e.g. `dev.sijun.HagaBible.bible.niv`).
    let id: String
    /// Localized product display name from the store.
    let displayName: String
    /// Localized price string from the store (e.g. "₩2,500", "$1.99").
    let displayPrice: String
}
