//
//  BibleVersionStoreViewModel.swift
//  HagaBible
//
//  Created by 양시준 on 6/6/26.
//

import Foundation
import Observation
import OSLog

/// Drives the Bible-version management screen: lists versions with their
/// purchase/download state and orchestrates acquire (purchase → download),
/// delete, and restore through the Domain use cases.
@Observable
@MainActor
final class BibleVersionStoreViewModel {
    private let loadCatalogUseCase: LoadBibleVersionCatalogUseCase
    private let acquireUseCase: AcquireBibleVersionUseCase
    private let restoreUseCase: RestorePurchasesUseCase
    private let fileRepository: BibleFileRepository

    /// The versions to display, with merged purchase + download state.
    var items: [BibleVersionItem] = []
    /// The version code currently being processed (purchase/download/delete), if any.
    var processingVersionCode: String?
    /// Whether a restore-purchases operation is in flight.
    var isRestoring = false
    /// A user-facing error message to present, if any.
    var errorMessage: String?

    /// True while any blocking operation is in progress.
    var isProcessing: Bool { processingVersionCode != nil || isRestoring }

    init(
        loadCatalogUseCase: LoadBibleVersionCatalogUseCase,
        acquireUseCase: AcquireBibleVersionUseCase,
        restoreUseCase: RestorePurchasesUseCase,
        fileRepository: BibleFileRepository
    ) {
        self.loadCatalogUseCase = loadCatalogUseCase
        self.acquireUseCase = acquireUseCase
        self.restoreUseCase = restoreUseCase
        self.fileRepository = fileRepository
    }

    /// Loads (or refreshes) the catalog from the repository + store.
    func load() async {
        items = await loadCatalogUseCase.execute()
    }

    /// Acquire a version: purchase if needed, then download & install.
    func acquire(_ item: BibleVersionItem) async {
        guard processingVersionCode == nil else { return }
        processingVersionCode = item.version.versionCode
        defer { processingVersionCode = nil }

        do {
            let outcome = try await acquireUseCase.execute(version: item.version)
            switch outcome {
            case .installed:
                await load()
            case .cancelled:
                break // user backed out; nothing to report
            case .pending:
                errorMessage = "Your purchase is pending approval. The version will be available once it's approved."
            }
        } catch {
            Logger.repository.error("Failed to acquire \(item.version.versionCode): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a downloaded version's local file (the entitlement is retained).
    func delete(_ item: BibleVersionItem) async {
        guard processingVersionCode == nil else { return }
        processingVersionCode = item.version.versionCode
        defer { processingVersionCode = nil }

        do {
            try await fileRepository.delete(version: item.version)
            await load()
        } catch {
            Logger.repository.error("Failed to delete \(item.version.versionCode): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Restore previously purchased entitlements, then refresh the catalog.
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await restoreUseCase.execute()
            await load()
        } catch {
            Logger.repository.error("Failed to restore purchases: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
