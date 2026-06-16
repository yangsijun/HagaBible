//
//  AcquireBibleVersionUseCase.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

/// Result of attempting to acquire (purchase if needed, then install) a version.
enum AcquireOutcome: Equatable, Sendable {
    /// Purchase (if any) succeeded and the version was downloaded & installed.
    case installed
    /// The user cancelled the purchase sheet; nothing was installed.
    case cancelled
    /// The purchase is pending external approval; nothing was installed yet.
    case pending
}

/// Orchestrates getting a Bible version onto the device:
/// - free version → download & install
/// - paid & already owned → download & install
/// - paid & not owned → purchase, then (on success) download & install
///
/// Keeps the purchase/download orchestration out of the UI layer.
protocol AcquireBibleVersionUseCase: Sendable {
    func execute(version: BibleVersion) async throws -> AcquireOutcome
}

final class DefaultAcquireBibleVersionUseCase: AcquireBibleVersionUseCase {
    private let store: BibleVersionStore
    private let fileRepository: BibleFileRepository

    init(store: BibleVersionStore, fileRepository: BibleFileRepository) {
        self.store = store
        self.fileRepository = fileRepository
    }

    func execute(version: BibleVersion) async throws -> AcquireOutcome {
        if let productID = BibleVersionPurchaseCatalog.productID(for: version.versionCode) {
            let owned = await store.purchasedProductIDs()
            if !owned.contains(productID) {
                switch try await store.purchase(productID: productID) {
                case .userCancelled:
                    return .cancelled
                case .pending:
                    return .pending
                case .success:
                    break // fall through to install
                }
            }
        }

        try await fileRepository.downloadAndInstall(version: version)
        return .installed
    }
}
