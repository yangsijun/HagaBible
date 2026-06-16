//
//  BibleVersionItem.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// A Bible version paired with its acquisition status, ready for the version
/// management UI. Combines the catalog/download state (`BibleVersion`) with the
/// purchase dimension (`Availability`).
struct BibleVersionItem: Equatable, Identifiable, Sendable {
    let version: BibleVersion
    let availability: Availability

    var id: String { version.versionCode }
    var isDownloaded: Bool { version.isDownloaded }

    /// The purchase dimension, orthogonal to download state.
    enum Availability: Equatable, Sendable {
        /// No purchase required — freely downloadable.
        case free
        /// Paid and owned (purchased or restored) — freely downloadable.
        case purchased
        /// Paid and not owned — must be purchased before downloading.
        /// `displayPrice` is the live localized price (empty if the store
        /// hasn't returned product info yet).
        case locked(displayPrice: String)
    }

    /// Whether the version may be downloaded/installed without a purchase step.
    var isOwned: Bool {
        switch availability {
        case .free, .purchased: return true
        case .locked: return false
        }
    }
}
