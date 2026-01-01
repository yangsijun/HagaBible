//
//  Logger.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.hagabible"

    /// Database operations logging
    static let database = Logger(subsystem: subsystem, category: "Database")

    /// Audio recording and playback logging
    static let audio = Logger(subsystem: subsystem, category: "Audio")

    /// Bible data repository operations logging
    static let repository = Logger(subsystem: subsystem, category: "Repository")

    /// Search functionality logging
    static let search = Logger(subsystem: subsystem, category: "Search")

    /// General application logging
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Text-to-Speech logging
    static let tts = Logger(subsystem: subsystem, category: "TTS")
}
