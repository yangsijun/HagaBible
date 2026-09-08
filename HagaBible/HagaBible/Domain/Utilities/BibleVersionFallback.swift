//
//  BibleVersionFallback.swift
//  HagaBible
//
//  Created by 양시준 on 9/8/26.
//

/// Picks the version the reader should actually open when the one it wants may not be
/// on the device.
///
/// The reader must never sit on an empty page: a version whose file is missing (deleted,
/// never finished downloading, geo-blocked) is swapped for one that can be read, keeping
/// the user's book/chapter/verse — `book_code` is the same standard code in every version.
enum BibleVersionFallback {
    /// The preferred version when it is downloaded; otherwise a downloaded version in the
    /// same language, then any downloaded version; `nil` when nothing is downloaded.
    /// Catalog order decides ties, so the caller's ordering is the preference order.
    nonisolated static func resolve(preferred code: String, among versions: [BibleVersion]) -> BibleVersion? {
        let preferred = versions.first { $0.versionCode == code }
        if let preferred, preferred.isDownloaded {
            return preferred
        }

        let downloaded = versions.filter(\.isDownloaded)
        if let language = preferred?.language,
           let sameLanguage = downloaded.first(where: { $0.language == language }) {
            return sameLanguage
        }
        return downloaded.first
    }
}
