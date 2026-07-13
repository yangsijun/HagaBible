//
//  HagaBibleWidgetControl.swift
//  HagaBibleWidget
//
//  Created by 양시준 on 12/31/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct HagaBibleWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "hagabible_widget_control"
        ) {
            ControlWidgetButton(action: OpenAppIntent()) {
                Label("Haga Bible", systemImage: "book.fill")
            }
        }
        .displayName("Open Haga Bible")
        .description("Quickly launch Haga Bible from Control Centre.")
    }
}

/// Control Center control that jumps straight into the Search tab. A control can't take
/// text input, so this opens the app ready to search rather than running a query.
struct HagaBibleSearchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "hagabible_search_control"
        ) {
            ControlWidgetButton(action: OpenBibleSearchIntent()) {
                // Custom SF Symbol (open book + magnifying-glass badge) exported from the
                // SF Symbols app into the widget's asset catalog.
                Label("Bible Search", image: "custom.book.fill.badge.magnifyingglass")
            }
        }
        .displayName("Bible Search")
        .description("Open Haga Bible and start searching.")
    }
}

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Haga Bible"
    static var description = IntentDescription("Open Haga Bible app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Opens the app to the Search tab. This file is compiled into BOTH the widget extension
/// (where the control instantiates the intent) and the app target (via a pbxproj membership
/// exception). `supportedModes = .foreground(.immediate)` brings the app to the foreground and
/// runs `perform()` in the app's main process, where — under the `HAGABIBLE_APP` compilation
/// condition — it can drive `AppState` directly. No App Group or URL scheme needed.
/// (`OpenURLIntent` was a dead end here: it only accepts universal links, not custom schemes
/// like `hagabible://`.)
struct OpenBibleSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Bible Search"
    static var description = IntentDescription("Open Haga Bible and start searching.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        #if HAGABIBLE_APP
        await MainActor.run {
            DIContainer.registerDependenciesIfNeeded()
            let appState = DIContainer.shared.resolve(type: AppState.self)
            appState.selectedTab = .search
            appState.pendingSearchFocus = true
        }
        #endif
        return .result()
    }
}
