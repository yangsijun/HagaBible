//
//  RegionService.swift
//  HagaBible
//
//  Determines the user's current region for CLIENT-SIDE geo gating — purely a
//  UX nicety (hide a version the user can't get). The AUTHORITATIVE enforcement
//  is server-side in the `bible-version-url` Supabase Edge Function, because a
//  client region is spoofable (VPN, account region ≠ physical location).
//

import Foundation
import StoreKit

struct RegionService {
    /// Test override: when set, `currentRegionCandidates()` returns this verbatim
    /// instead of reading `Locale`/StoreKit. Production code leaves it `nil`.
    private let overrideCandidates: Set<String>?

    init(overrideCandidates: Set<String>? = nil) {
        self.overrideCandidates = overrideCandidates
    }

    /// Best-effort set of region codes for the current device/store account, in
    /// both alpha-2 (`Locale` region, e.g. "GB") and alpha-3 (StoreKit
    /// storefront, e.g. "GBR") forms so either can be matched.
    func currentRegionCandidates() async -> Set<String> {
        if let overrideCandidates { return overrideCandidates }
        var codes: Set<String> = []
        if let region = Locale.current.region?.identifier, !region.isEmpty {
            codes.insert(region.uppercased())
        }
        if let storefront = await Storefront.current?.countryCode, !storefront.isEmpty {
            codes.insert(storefront.uppercased())
        }
        return codes
    }

    /// Whether `versionCode` is download-restricted in the current region.
    func isDownloadRestricted(versionCode: String) async -> Bool {
        let restricted = BibleVersionDeliveryCatalog.restrictedRegions(for: versionCode)
        guard !restricted.isEmpty else { return false }
        let here = await currentRegionCandidates()
        return !here.isDisjoint(with: restricted)
    }
}
