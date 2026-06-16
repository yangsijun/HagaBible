//
//  StoreError.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

import Foundation

/// Errors surfaced by the in-app purchase store (StoreKit) layer.
enum StoreError: LocalizedError {
    /// The requested product identifier was not found in the store.
    case productNotFound
    /// A transaction failed StoreKit's cryptographic verification.
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "This item is not available in the store right now."
        case .failedVerification:
            return "The purchase could not be verified. Please try again."
        }
    }
}
