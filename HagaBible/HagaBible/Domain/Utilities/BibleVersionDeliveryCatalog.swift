//
//  BibleVersionDeliveryCatalog.swift
//  HagaBible
//
//  Single source of truth for HOW each Bible version is delivered and WHERE it
//  may be downloaded. Orthogonal to the purchase classification in
//  BibleVersionPurchaseCatalog.
//
//  - Most versions ship via On-Demand Resources (ODR) with a Supabase Storage
//    fallback (ODR is unavailable on the "Designed for iPad" Mac runtime, where
//    Apple's ODR CDN write fails with a permission error).
//  - Geo-restricted versions (KJV) are NOT shipped via ODR at all — ODR has no
//    per-asset territory control — and download ONLY through the geo-gated
//    Supabase Edge Function, which blocks restricted regions server-side.
//
//  KJV: the King James Version is under perpetual Crown copyright in the United
//  Kingdom (Cambridge University Press / royal letters patent) while being
//  public domain in the US and most of the world, so it must not be
//  downloadable in the UK.
//

enum BibleVersionDeliveryCatalog {
    /// `versionCode` → ISO region codes (both alpha-2 and alpha-3 forms, so the
    /// client can match either a `Locale` region or a StoreKit storefront) in
    /// which the version must NOT be downloadable. Absent = no geo limit.
    static let geoRestrictedRegions: [String: Set<String>] = [
        "KJV": ["GB", "GBR"],
    ]

    /// Regions where `versionCode` may not be downloaded (empty = unrestricted).
    static func restrictedRegions(for versionCode: String) -> Set<String> {
        geoRestrictedRegions[versionCode] ?? []
    }

    /// Whether the version is geographically restricted anywhere. Geo-restricted
    /// versions are delivered Supabase-only (never via ODR) so the server can
    /// enforce the territory block at download time.
    static func isGeoRestricted(_ versionCode: String) -> Bool {
        !restrictedRegions(for: versionCode).isEmpty
    }

    /// Whether the version is delivered via On-Demand Resources (with a Supabase
    /// fallback). Geo-restricted versions are excluded from ODR.
    static func usesODR(_ versionCode: String) -> Bool {
        !isGeoRestricted(versionCode)
    }
}
