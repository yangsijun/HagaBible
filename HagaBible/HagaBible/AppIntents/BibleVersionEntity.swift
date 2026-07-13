//
//  BibleVersionEntity.swift
//  HagaBible
//
//  An `AppEntity` wrapper for a Bible translation so the search App Intents can take an
//  optional "translation" parameter. Unlike a free-text `String`, an `AppEntity` renders
//  as a picker in the Shortcuts app (and can appear in Siri phrases). The candidate set is
//  the user's *downloaded* versions, read through the app's `BibleRepository`.
//

import AppIntents

struct BibleVersionEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bible Translation"
    static let defaultQuery = BibleVersionEntityQuery()

    /// versionCode (e.g. "KRV", "WEBBE").
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        // Verbatim: a translation name is dynamic content, not a localizable literal.
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct BibleVersionEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BibleVersionEntity] {
        let all = try await downloadedVersions()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [BibleVersionEntity] {
        try await downloadedVersions()
    }

    @MainActor
    private func downloadedVersions() async throws -> [BibleVersionEntity] {
        DIContainer.registerDependenciesIfNeeded()
        let repository = DIContainer.shared.resolve(type: BibleRepository.self)
        let versions = try await repository.fetchBibleVersionList()
        return versions
            .filter { $0.isDownloaded }
            .map { BibleVersionEntity(id: $0.versionCode, name: $0.versionName) }
    }
}
