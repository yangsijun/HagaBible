//
//  HagaBibleWidget.swift
//  HagaBibleWidget
//
//  Created by 양시준 on 12/31/25.
//

import WidgetKit
import SwiftUI

struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticEntry {
        StaticEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StaticEntry) -> ()) {
        let entry = StaticEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = StaticEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct StaticEntry: TimelineEntry {
    let date: Date
}

struct HagaBibleWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: StaticProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .padding(8)
                    .opacity(0.1)
                    .widgetAccentable()
                Image(systemName: "book.fill")
                    .widgetAccentable()
                    .font(.system(size: 22))
            }
        default:
            Rectangle()
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
    }
}

struct HagaBibleWidget: Widget {
    let kind: String = "hagabible_widget_dev"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StaticProvider()) { entry in
            if #available(iOS 17.0, *) {
                HagaBibleWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                HagaBibleWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Haga Bible")
        .description("Quick access to Haga Bible from your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular
        ])
    }
}

#Preview(as: .accessoryCircular) {
    HagaBibleWidget()
} timeline: {
    StaticEntry(date: .now)
}

#Preview(as: .accessoryRectangular) {
    HagaBibleWidget()
} timeline: {
    StaticEntry(date: .now)
}
