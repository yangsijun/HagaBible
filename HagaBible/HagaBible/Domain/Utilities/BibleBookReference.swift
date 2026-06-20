//
//  BibleBookReference.swift
//  HagaBible
//
//  Created by Codex on 6/20/26.
//

import Foundation

/// Version-independent Bible book metadata used to resolve a free-text reference
/// (typed in any language) to a canonical book code.
///
/// Every version database shares the same OSIS-style `bookCode` (e.g. `"GEN"`),
/// while the human-readable `book_name` differs per version/language. Resolving a
/// query to a `bookCode` therefore lets the reader accept a Korean *or* English
/// reference regardless of which version is currently loaded, then display the
/// loaded version's own localized name.
///
/// The alias table is derived from the bundled version databases (KRV, NKRV, NIV,
/// KJV, WEB, WEBBE) and is collision-free: no normalized alias maps to two books.
enum BibleBookReference {
    /// Maps a normalized alias to its canonical `bookCode`.
    ///
    /// Includes every book's full name and abbreviations in both Korean and
    /// English, plus the canonical code itself (so `"psa"`, `"exo"`, ... resolve).
    private static let aliasToBookCode: [String: String] = {
        var map: [String: String] = [:]
        for (code, aliases) in rawAliases {
            // The canonical code itself is always a valid query (e.g. "GEN", "psa").
            map[normalize(code)] = code
            for alias in aliases {
                map[alias] = code
            }
        }
        return map
    }()

    /// Resolves a free-text book token (any language or abbreviation) to its
    /// canonical `bookCode`, or `nil` when unrecognized.
    static func bookCode(for query: String) -> String? {
        let normalized = normalize(query)
        guard !normalized.isEmpty else { return nil }
        return aliasToBookCode[normalized]
    }

    /// Minimum normalized query length for loose matching. Shorter queries (a
    /// single Korean syllable or one Latin letter) match too many books to be
    /// useful, so they are only honored by exact `bookCode(for:)` matching.
    private static let minimumLooseQueryLength = 2

    /// Resolves a partial book token to canonical `bookCode`s via loose matching,
    /// ranked best-first, for as-you-type reference search (e.g. `"창세"` →
    /// `["GEN"]`, `"고린"` → `["1CO", "2CO"]`, `"genes"` → `["GEN"]`).
    ///
    /// Ranking is deterministic:
    /// 1. An exact alias match, if any, is always returned alone.
    /// 2. Otherwise books whose alias *starts with* the query (prefix matches)
    ///    rank ahead of books where the query only appears mid-alias (substring
    ///    matches).
    /// 3. Within each tier, books are ordered by canonical book order, so an
    ///    ambiguous prefix resolves to the earliest book (`"요한"` → 요한복음).
    ///
    /// Returns an empty array for queries shorter than ``minimumLooseQueryLength``
    /// or with no match. Callers that need a single result take `.first`.
    static func looseBookCodes(for query: String) -> [String] {
        let normalized = normalize(query)
        guard normalized.count >= minimumLooseQueryLength else {
            // Still honor an exact match for short but valid tokens (e.g. "약").
            return aliasToBookCode[normalized].map { [$0] } ?? []
        }

        if let exact = aliasToBookCode[normalized] {
            return [exact]
        }

        var prefixMatches: Set<String> = []
        var substringMatches: Set<String> = []
        for (alias, code) in aliasToBookCode {
            if alias.hasPrefix(normalized) {
                prefixMatches.insert(code)
            } else if alias.contains(normalized) {
                substringMatches.insert(code)
            }
        }

        // Prefix matches outrank substring-only matches; never list a book twice.
        let ranked = canonicalOrder.filter { prefixMatches.contains($0) }
            + canonicalOrder.filter { substringMatches.contains($0) && !prefixMatches.contains($0) }
        return ranked
    }

    /// Lowercases and strips all whitespace so that `"1 Samuel"`, `"1Samuel"`, and
    /// `"  1 SAMUEL "` all match the same stored alias.
    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { !$0.isWhitespace }
    }

    /// Canonical book codes in scripture order, used to break ties deterministically
    /// when a loose query matches more than one book.
    private static let canonicalOrder: [String] = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
        "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
        "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
        "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT",
        "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP",
        "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE",
        "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
    ]

    /// Normalized aliases keyed by canonical `bookCode`, generated from the bundled
    /// version databases. Each entry is lowercased and whitespace-stripped.
    private static let rawAliases: [String: [String]] = [
        "GEN": ["gen", "genesis", "gn", "창", "창세기"],
        "EXO": ["ex", "exod", "exodus", "출", "출애굽기"],
        "LEV": ["lev", "leviticus", "lv", "레", "레위기"],
        "NUM": ["nm", "num", "numbers", "민", "민수기"],
        "DEU": ["deut", "deuteronomy", "dt", "신", "신명기"],
        "JOS": ["jos", "josh", "joshua", "수", "여호수아"],
        "JDG": ["jdg", "judg", "judges", "사사기", "삿"],
        "RUT": ["ru", "ruth", "룻", "룻기"],
        "1SA": ["1sam", "1samuel", "1sm", "사무엘상", "삼상"],
        "2SA": ["2sam", "2samuel", "2sm", "사무엘하", "삼하"],
        "1KI": ["1kgs", "1kings", "1ki", "열왕기상", "왕상"],
        "2KI": ["2kgs", "2kings", "2ki", "열왕기하", "왕하"],
        "1CH": ["1chr", "1chronicles", "1ch", "대상", "역대상"],
        "2CH": ["2chr", "2chronicles", "2ch", "대하", "역대하"],
        "EZR": ["ezr", "ezra", "스", "에스라"],
        "NEH": ["ne", "neh", "nehemiah", "느", "느헤미야"],
        "EST": ["est", "esth", "esther", "에", "에스더"],
        "JOB": ["jb", "job", "욥", "욥기"],
        "PSA": ["ps", "psalm", "psalms", "pss", "시", "시편"],
        "PRO": ["pr", "prov", "proverbs", "prv", "잠", "잠언"],
        "ECC": ["ec", "ecc", "eccl", "ecclesiastes", "전", "전도서"],
        "SNG": ["sg", "sos", "song", "songofsolomon", "아", "아가"],
        "ISA": ["is", "isa", "isaiah", "사", "이사야"],
        "JER": ["je", "jer", "jeremiah", "렘", "예레미야"],
        "LAM": ["la", "lam", "lamentations", "애", "예레미야애가"],
        "EZK": ["ez", "ezek", "ezekiel", "ezk", "겔", "에스겔"],
        "DAN": ["dan", "daniel", "dn", "다니엘", "단"],
        "HOS": ["ho", "hos", "hosea", "호", "호세아"],
        "JOL": ["jl", "joel", "요엘", "욜"],
        "AMO": ["am", "amos", "아모스", "암"],
        "OBA": ["ob", "obad", "obadiah", "오바댜", "옵"],
        "JON": ["jon", "jonah", "요나", "욘"],
        "MIC": ["mi", "mic", "micah", "미", "미가"],
        "NAM": ["na", "nah", "nahum", "나", "나훔"],
        "HAB": ["hab", "habakkuk", "hb", "하박국", "합"],
        "ZEP": ["zep", "zeph", "zephaniah", "스바냐", "습"],
        "HAG": ["hag", "haggai", "hg", "학", "학개"],
        "ZEC": ["zec", "zech", "zechariah", "스가랴", "슥"],
        "MAL": ["mal", "malachi", "ml", "말", "말라기"],
        "MAT": ["matt", "matthew", "mt", "마", "마태복음"],
        "MRK": ["mark", "mk", "mrk", "마가복음", "막"],
        "LUK": ["lk", "luk", "luke", "누가복음", "눅"],
        "JHN": ["jhn", "jn", "john", "요", "요한복음"],
        "ACT": ["ac", "acts", "사도행전", "행"],
        "ROM": ["ro", "rom", "romans", "로마서", "롬"],
        "1CO": ["1cor", "1corinthians", "1co", "고린도전서", "고전"],
        "2CO": ["2cor", "2corinthians", "2co", "고린도후서", "고후"],
        "GAL": ["ga", "gal", "galatians", "갈", "갈라디아서"],
        "EPH": ["ep", "eph", "ephesians", "에베소서", "엡"],
        "PHP": ["phil", "philippians", "php", "빌", "빌립보서"],
        "COL": ["co", "col", "colossians", "골", "골로새서"],
        "1TH": ["1thess", "1thessalonians", "1th", "데살로니가전서", "살전"],
        "2TH": ["2thess", "2thessalonians", "2th", "데살로니가후서", "살후"],
        "1TI": ["1tim", "1timothy", "1ti", "디모데전서", "딤전"],
        "2TI": ["2tim", "2timothy", "2ti", "디모데후서", "딤후"],
        "TIT": ["ti", "tit", "titus", "디도서", "딛"],
        "PHM": ["philem", "philemon", "phlm", "phm", "몬", "빌레몬서"],
        "HEB": ["he", "heb", "hebrews", "히", "히브리서"],
        "JAS": ["james", "jas", "jm", "야고보서", "약"],
        "1PE": ["1pet", "1peter", "1pt", "베드로전서", "벧전"],
        "2PE": ["2pet", "2peter", "2pt", "베드로후서", "벧후"],
        "1JN": ["1john", "1jn", "요일", "요한일서"],
        "2JN": ["2john", "2jn", "요이", "요한이서"],
        "3JN": ["3john", "3jn", "요삼", "요한삼서"],
        "JUD": ["jd", "jude", "유", "유다서"],
        "REV": ["re", "rev", "revelation", "rv", "계", "요한계시록"],
    ]
}
