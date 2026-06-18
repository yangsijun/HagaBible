//
//  Logger.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import OSLog

extension Logger {
    private nonisolated static let subsystem = "dev.sijun.HagaBible"

    nonisolated static let database = Logger(subsystem: subsystem, category: "Database")
    nonisolated static let audio = Logger(subsystem: subsystem, category: "Audio")
    nonisolated static let repository = Logger(subsystem: subsystem, category: "Repository")
    nonisolated static let search = Logger(subsystem: subsystem, category: "Search")
    nonisolated static let app = Logger(subsystem: subsystem, category: "App")
    nonisolated static let tts = Logger(subsystem: subsystem, category: "TTS")
    nonisolated static let notification = Logger(subsystem: subsystem, category: "Notification")
}
