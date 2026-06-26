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
    /// The geo gate returned an unexpected or malformed response.
    case invalidResponse
    /// The signed-URL download itself failed with a non-success status.
    case downloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .regionRestricted:
            return String(localized: "This version isn't available for download in your region.")
        case .invalidResponse:
            return String(localized: "Couldn't reach the download service. Please try again.")
        case .downloadFailed:
            return String(localized: "The download failed. Please try again.")
        }
    }
}
