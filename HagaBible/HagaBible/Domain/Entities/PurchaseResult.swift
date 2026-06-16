//
//  PurchaseResult.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// Outcome of an attempt to purchase a product, abstracted away from StoreKit.
enum PurchaseResult: Equatable, Sendable {
    /// The purchase completed and the entitlement is now owned.
    case success
    /// The user dismissed the purchase sheet without buying.
    case userCancelled
    /// The purchase is pending external action (e.g. Ask to Buy / SCA approval).
    case pending
}
