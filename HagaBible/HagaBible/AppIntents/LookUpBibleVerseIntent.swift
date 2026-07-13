//
//  LookUpBibleVerseIntent.swift
//  HagaBible
//
//  App Shortcut / Siri / Spotlight entry point for 주소검색 (address lookup) that
//  returns the verse text INLINE — without opening the app. Resolves the reference
//  offline, reads the verse from the local database (in the app's process), and hands
//  Siri/Spotlight both a spoken/printed dialog and a snippet card with an
//  "Open in Reader" button (which runs `OpenBibleReferenceIntent`).
//

import AppIntents
import SwiftUI

struct LookUpBibleVerseIntent: AppIntent {
    static let title: LocalizedStringResource = "Look Up a Bible Verse"
    static let description = IntentDescription("Look up a Bible reference and show the verse text.")

    // Runs in the background (does not open the app) so the verse can be shown inline.
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Bible Reference", requestValueDialog: "Which verse? (e.g. John 3:16)")
    var reference: String

    // Optional — defaults to the reader's current / last translation when left unset.
    @Parameter(title: "Translation")
    var version: BibleVersionEntity?

    init() {}

    init(reference: String, version: BibleVersionEntity? = nil) {
        self.reference = reference
        self.version = version
    }

    // Runs on the main actor (the module defaults to `MainActor` isolation); the async
    // database reads still suspend off the main thread internally.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        DIContainer.registerDependenciesIfNeeded()
        let repository = DIContainer.shared.resolve(type: BibleRepository.self)

        guard let resolved = BibleReferenceResolver.resolve(reference) else {
            throw BibleLookupError.unresolvedReference
        }

        guard let versionCode = await Self.resolveVersionCode(chosen: version, repository: repository) else {
            throw BibleLookupError.noVersionAvailable
        }

        guard let verse = try await repository.fetchBibleVerse(
            versionCode: versionCode,
            bookCode: resolved.bookCode,
            chapter: resolved.chapter,
            verse: resolved.verse
        ) else {
            throw BibleLookupError.verseNotFound
        }

        let referenceLabel = "\(verse.bookName) \(verse.chapter):\(verse.verse)"
        let verseText = verse.verseText ?? ""
        // Verse text is dynamic runtime content, not a localizable literal — build the
        // dialog verbatim to avoid the unlocalized-interpolation warning.
        let dialog = IntentDialog(stringLiteral: "\(referenceLabel)\n\(verseText)")
        return .result(
            dialog: dialog,
            view: VerseSnippetView(reference: referenceLabel, verseText: verseText, rawReference: reference)
        )
    }

    /// The translation to read from: the explicitly-chosen version if given, else the
    /// reader's current / last-saved version, else any downloaded version.
    @MainActor
    private static func resolveVersionCode(chosen: BibleVersionEntity?, repository: BibleRepository) async -> String? {
        if let chosen {
            return chosen.id
        }
        let appState = DIContainer.shared.resolve(type: AppState.self)
        if let current = appState.bibleReaderState.bibleVersion?.versionCode {
            return current
        }
        if let restored = appState.restoredReaderPosition?.versionCode {
            return restored
        }
        let versions = try? await repository.fetchBibleVersionList()
        return versions?.first(where: { $0.isDownloaded })?.versionCode
    }
}

enum BibleLookupError: Error, CustomLocalizedStringResourceConvertible {
    case unresolvedReference
    case noVersionAvailable
    case verseNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unresolvedReference:
            return "Couldn't recognize that Bible reference."
        case .noVersionAvailable:
            return "No Bible translation is downloaded yet. Open the app first."
        case .verseNotFound:
            return "Couldn't find that verse."
        }
    }
}

/// Inline snippet shown by Siri / Spotlight for a looked-up verse.
private struct VerseSnippetView: View {
    let reference: String
    let verseText: String
    let rawReference: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reference)
                .font(.headline)
            Text(verseText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Button(intent: OpenBibleReferenceIntent(reference: rawReference)) {
                Label("Open in Reader", systemImage: "book.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
