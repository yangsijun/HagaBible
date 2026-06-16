//
//  RestorePurchasesUseCase.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// Restores previously purchased entitlements from the App Store. Required by
/// App Store Review Guidelines for any app selling non-consumable content.
protocol RestorePurchasesUseCase: Sendable {
    func execute() async throws
}

final class DefaultRestorePurchasesUseCase: RestorePurchasesUseCase {
    private let store: BibleVersionStore

    init(store: BibleVersionStore) {
        self.store = store
    }

    func execute() async throws {
        try await store.restore()
    }
}
