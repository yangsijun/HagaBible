import Testing
@testable import HagaBible

@Suite("Bible content update: outdated files and reader fallback")
struct BibleContentUpdateTests {
    private func version(_ code: String, _ language: String, downloaded: Bool) -> BibleVersion {
        BibleVersion(versionCode: code, versionName: code, versionShortName: code, language: language, isDownloaded: downloaded)
    }

    // MARK: Outdated detection (files are kept, only flagged)

    @Test("A file whose saved content version differs from the catalog is outdated")
    func mismatchIsOutdated() {
        let current = BibleVersionDeliveryCatalog.contentVersion(for: "NKRV")
        let stale = current + "_old"
        let outdated = BibleDatabaseService.outdatedVersionCodes(
            installed: ["NKRV", "WEBBE"],
            savedVersions: ["NKRV": stale, "WEBBE": BibleVersionDeliveryCatalog.contentVersion(for: "WEBBE")]
        )
        #expect(outdated == ["NKRV"])
    }

    @Test("A file with no recorded content version counts as outdated")
    func missingRecordIsOutdated() {
        let outdated = BibleDatabaseService.outdatedVersionCodes(installed: ["KRV"], savedVersions: [:])
        #expect(outdated == ["KRV"])
    }

    @Test("Files matching the catalog are not outdated")
    func matchingIsCurrent() {
        let saved = Dictionary(uniqueKeysWithValues: ["NKRV", "KRV", "WEBBE"].map {
            ($0, BibleVersionDeliveryCatalog.contentVersion(for: $0))
        })
        #expect(BibleDatabaseService.outdatedVersionCodes(installed: ["NKRV", "KRV", "WEBBE"], savedVersions: saved).isEmpty)
    }

    // MARK: Reader fallback

    @Test("A downloaded preferred version is used as is")
    func preferredWhenDownloaded() {
        let versions = [version("NKRV", "Korean", downloaded: true), version("KRV", "Korean", downloaded: true)]
        #expect(BibleVersionFallback.resolve(preferred: "NKRV", among: versions)?.versionCode == "NKRV")
    }

    @Test("A missing preferred version falls back to the same language first")
    func sameLanguageFirst() {
        let versions = [
            version("WEBBE", "English", downloaded: true),
            version("NKRV", "Korean", downloaded: false),
            version("KRV", "Korean", downloaded: true),
        ]
        #expect(BibleVersionFallback.resolve(preferred: "NKRV", among: versions)?.versionCode == "KRV")
    }

    @Test("Without a same-language version any downloaded version is used")
    func anyDownloadedOtherwise() {
        let versions = [
            version("NKRV", "Korean", downloaded: false),
            version("WEBBE", "English", downloaded: true),
        ]
        #expect(BibleVersionFallback.resolve(preferred: "NKRV", among: versions)?.versionCode == "WEBBE")
    }

    @Test("An unknown preferred code still lands on a downloaded version")
    func unknownCodeFallsBack() {
        let versions = [version("KRV", "Korean", downloaded: true)]
        #expect(BibleVersionFallback.resolve(preferred: "XYZ", among: versions)?.versionCode == "KRV")
    }

    @Test("Nothing downloaded resolves to nil (reader shows the empty state)")
    func nothingDownloadedIsNil() {
        let versions = [version("NKRV", "Korean", downloaded: false), version("WEBBE", "English", downloaded: false)]
        #expect(BibleVersionFallback.resolve(preferred: "NKRV", among: versions) == nil)
        #expect(BibleVersionFallback.resolve(preferred: "NKRV", among: []) == nil)
    }
}
