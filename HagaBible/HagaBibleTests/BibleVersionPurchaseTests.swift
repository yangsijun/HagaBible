//
//  BibleVersionPurchaseTests.swift
//  HagaBibleTests
//

import Testing
import Foundation
@testable import HagaBible

// MARK: - Catalog

@Suite("BibleVersionPurchaseCatalog")
struct BibleVersionPurchaseCatalogTests {
    @Test("Paid versions resolve to a product id; free versions do not")
    func paidVersusFreeClassification() {
        #expect(BibleVersionPurchaseCatalog.productID(for: "NIV") == "dev.sijun.HagaBible.bible.niv")
        #expect(BibleVersionPurchaseCatalog.isFree("NIV") == false)

        #expect(BibleVersionPurchaseCatalog.productID(for: "KJV") == nil)
        #expect(BibleVersionPurchaseCatalog.isFree("KJV") == true)
        #expect(BibleVersionPurchaseCatalog.isFree("WEB") == true)
    }

    @Test("allProductIDs covers every paid product")
    func allProductIDsCoversPaid() {
        #expect(BibleVersionPurchaseCatalog.allProductIDs.contains("dev.sijun.HagaBible.bible.niv"))
        #expect(BibleVersionPurchaseCatalog.allProductIDs.contains("dev.sijun.HagaBible.bible.nkrv"))
    }
}

// MARK: - LoadBibleVersionCatalogUseCase

@MainActor
@Suite("LoadBibleVersionCatalogUseCase")
struct LoadBibleVersionCatalogUseCaseTests {
    private func makeVersion(_ code: String) -> BibleVersion {
        BibleVersion(versionCode: code, versionName: code, versionShortName: code, language: "English", isDownloaded: false)
    }

    @Test("Free versions are .free, owned paid versions are .purchased, unowned paid versions are .locked with price")
    func availabilityMapping() async {
        let repo = StubVersionListRepository(versions: [
            makeVersion("KJV"),  // free
            makeVersion("NIV"),  // paid, not owned
            makeVersion("NKRV"), // paid, owned
        ])
        let store = MockBibleVersionStore(
            availableProducts: [
                StoreProduct(id: "dev.sijun.HagaBible.bible.niv", displayName: "NIV", displayPrice: "$2.99"),
                StoreProduct(id: "dev.sijun.HagaBible.bible.nkrv", displayName: "개역개정", displayPrice: "₩3,900"),
            ],
            ownedProductIDs: ["dev.sijun.HagaBible.bible.nkrv"]
        )
        let useCase = DefaultLoadBibleVersionCatalogUseCase(bibleRepository: repo, store: store)

        let items = await useCase.execute()

        #expect(items.count == 3)
        #expect(items.first { $0.id == "KJV" }?.availability == .free)
        #expect(items.first { $0.id == "NIV" }?.availability == .locked(displayPrice: "$2.99"))
        #expect(items.first { $0.id == "NKRV" }?.availability == .purchased)
    }
}

// MARK: - AcquireBibleVersionUseCase

@MainActor
@Suite("AcquireBibleVersionUseCase")
struct AcquireBibleVersionUseCaseTests {
    private func makeVersion(_ code: String) -> BibleVersion {
        BibleVersion(versionCode: code, versionName: code, versionShortName: code, language: "English", isDownloaded: false)
    }

    @Test("Free version installs without any purchase")
    func freeInstallsWithoutPurchase() async throws {
        let store = MockBibleVersionStore()
        let fileRepo = MockBibleFileRepository()
        let useCase = DefaultAcquireBibleVersionUseCase(store: store, fileRepository: fileRepo)

        let outcome = try await useCase.execute(version: makeVersion("KJV"))

        #expect(outcome == .installed)
        #expect(store.purchaseCallProductIDs.isEmpty)
        #expect(fileRepo.downloadedVersionCodes == ["KJV"])
    }

    @Test("Paid + unowned purchases then installs")
    func paidUnownedPurchasesThenInstalls() async throws {
        let store = MockBibleVersionStore(ownedProductIDs: [], nextPurchaseResult: .success)
        let fileRepo = MockBibleFileRepository()
        let useCase = DefaultAcquireBibleVersionUseCase(store: store, fileRepository: fileRepo)

        let outcome = try await useCase.execute(version: makeVersion("NIV"))

        #expect(outcome == .installed)
        #expect(store.purchaseCallProductIDs == ["dev.sijun.HagaBible.bible.niv"])
        #expect(fileRepo.downloadedVersionCodes == ["NIV"])
    }

    @Test("Paid + already owned installs without re-purchasing")
    func paidOwnedInstallsWithoutPurchase() async throws {
        let store = MockBibleVersionStore(ownedProductIDs: ["dev.sijun.HagaBible.bible.niv"])
        let fileRepo = MockBibleFileRepository()
        let useCase = DefaultAcquireBibleVersionUseCase(store: store, fileRepository: fileRepo)

        let outcome = try await useCase.execute(version: makeVersion("NIV"))

        #expect(outcome == .installed)
        #expect(store.purchaseCallProductIDs.isEmpty)
        #expect(fileRepo.downloadedVersionCodes == ["NIV"])
    }

    @Test("Cancelled purchase does not install")
    func cancelledPurchaseDoesNotInstall() async throws {
        let store = MockBibleVersionStore(ownedProductIDs: [], nextPurchaseResult: .userCancelled)
        let fileRepo = MockBibleFileRepository()
        let useCase = DefaultAcquireBibleVersionUseCase(store: store, fileRepository: fileRepo)

        let outcome = try await useCase.execute(version: makeVersion("NIV"))

        #expect(outcome == .cancelled)
        #expect(fileRepo.downloadedVersionCodes.isEmpty)
    }

    @Test("Pending purchase does not install")
    func pendingPurchaseDoesNotInstall() async throws {
        let store = MockBibleVersionStore(ownedProductIDs: [], nextPurchaseResult: .pending)
        let fileRepo = MockBibleFileRepository()
        let useCase = DefaultAcquireBibleVersionUseCase(store: store, fileRepository: fileRepo)

        let outcome = try await useCase.execute(version: makeVersion("NIV"))

        #expect(outcome == .pending)
        #expect(fileRepo.downloadedVersionCodes.isEmpty)
    }
}

// MARK: - RestorePurchasesUseCase

@MainActor
@Suite("RestorePurchasesUseCase")
struct RestorePurchasesUseCaseTests {
    @Test("Restore delegates to the store")
    func restoreDelegates() async throws {
        let store = MockBibleVersionStore()
        let useCase = DefaultRestorePurchasesUseCase(store: store)

        try await useCase.execute()

        #expect(store.restoreCallCount == 1)
    }
}

// MARK: - Test doubles

/// Minimal `BibleRepository` returning a fixed version list; other methods unused.
private final class StubVersionListRepository: BibleRepository, @unchecked Sendable {
    private let versions: [BibleVersion]
    init(versions: [BibleVersion]) { self.versions = versions }

    func fetchBibleVersionList() async throws -> [BibleVersion] { versions }
    func fetchBibleBookList(versionCode: String) async throws -> [BibleBook] { [] }
    func fetchBibleChapterList(versionCode: String, bookCode: String) async throws -> [BibleChapter] { [] }
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapter: Int) async throws -> [BibleVerse] { [] }
    func fetchBibleVerse(versionCode: String, bookCode: String, chapter: Int, verse: Int) async throws -> BibleVerse? { nil }
    func findByVerseTextContaining(versionCode: String, keyword: String) async throws -> [BibleVerse] { [] }
    func findBookCodeByAbbreviation(versionCode: String, abbreviation: String) async throws -> String? { nil }
}
