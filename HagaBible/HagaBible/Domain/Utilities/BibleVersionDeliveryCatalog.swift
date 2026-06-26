//
//  BibleVersionDeliveryCatalog.swift
//  HagaBible
//
//  Single source of truth for HOW each Bible version is delivered and WHERE it
//  may be downloaded. Orthogonal to the purchase classification in
//  BibleVersionPurchaseCatalog.
//
//  - Free, public-domain versions (KRV, WEB, WEBBE) ship via On-Demand Resources
//    (ODR) with a direct download from the PUBLIC Supabase bucket as a fallback
//    (ODR is unavailable on the "Designed for iPad" Mac runtime, where Apple's
//    ODR CDN write fails with a permission error).
//  - Geo-restricted versions (KJV) are NOT shipped via ODR at all — ODR has no
//    per-asset territory control — and download ONLY through the geo-gated
//    Supabase Edge Function, which blocks restricted regions server-side.
//  - Paid versions (NIV, NKRV) keep ODR as the primary path, but their Supabase
//    fallback never uses the public bucket: a plain public URL would let anyone
//    download licensed, paid content for free. Instead they go through the Edge
//    Function, which verifies the caller's StoreKit purchase (Apple-signed JWS)
//    server-side before issuing a short-lived signed URL to the PRIVATE bucket.
//
//  In short, the PUBLIC bucket holds only free public-domain versions; every
//  gated version (geo OR purchase) lives in the private bucket behind the Edge
//  Function. The "is it paid?" classification is owned by
//  BibleVersionPurchaseCatalog; this catalog only decides delivery/routing.
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
    /// fallback). Geo-restricted versions are excluded from ODR. Paid versions
    /// KEEP ODR as their primary path — only their *fallback* is hardened (it
    /// goes through the purchase-verifying Edge Function, not the public bucket).
    static func usesODR(_ versionCode: String) -> Bool {
        !isGeoRestricted(versionCode)
    }

    /// Whether downloading this version from Supabase requires proving a
    /// StoreKit purchase to the server (the Edge Function verifies the signed
    /// transaction before issuing a signed URL). True for every paid version.
    static func requiresPurchaseVerification(_ versionCode: String) -> Bool {
        !BibleVersionPurchaseCatalog.isFree(versionCode)
    }

    /// Whether the version is served straight from the PUBLIC Supabase bucket
    /// (no server-side gate). Only free, public-domain versions qualify; geo- or
    /// purchase-gated versions are served from the private bucket via the Edge
    /// Function so they are never exposed at a plain, predictable public URL.
    static func usesPublicBucket(_ versionCode: String) -> Bool {
        !isGeoRestricted(versionCode) && !requiresPurchaseVerification(versionCode)
    }
}
