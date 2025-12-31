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

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Haga Bible"
    static var description = IntentDescription("Open Haga Bible app.")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        .result()
    }
}
