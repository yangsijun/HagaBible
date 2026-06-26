//
//  BibleDownloadError.swift
//  HagaBible
//
//  Errors surfaced by the Supabase download path (and its geo gate).
//

import Foundation

enum BibleDownloadError: LocalizedError {
    /// The version is not available for download in the user's region (e.g. KJV
    /// in the UK), enforced server-side by the geo-gating Edge Function.
    case regionRestricted
    /// The server could not verify a StoreKit purchase for a paid version (no
    /// entitlement on device, or the Edge Function rejected the signed
    /// transaction). Enforced server-side before any signed URL is issued.
    case notPurchased
    /// The geo gate returned an unexpected or malformed response.
    case invalidResponse
    /// The signed-URL download itself failed with a non-success status.
    case downloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .regionRestricted:
            return String(localized: "This version isn't available for download in your region.")
        case .notPurchased:
            return String(localized: "We couldn't confirm your purchase of this version. Please try again or restore your purchases.")
        case .invalidResponse:
            return String(localized: "Couldn't reach the download service. Please try again.")
        case .downloadFailed:
            return String(localized: "The download failed. Please try again.")
        }
    }
}
