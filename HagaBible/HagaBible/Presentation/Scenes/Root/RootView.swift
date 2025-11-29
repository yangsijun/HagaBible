//
//  ContentView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var appState = DIContainer.shared.resolve(type: AppState.self)
    @State private var search: String = ""
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("Bible", systemImage: "book.fill", value: .bibleReader) {
                BibleReaderView()
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            Tab("Recordings", systemImage: "waveform", value: .recordings) {
                RecordingsView()
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(searchText: $search)
                    .environment(\.horizontalSizeClass, horizontalSizeClass)
                    .searchable(text: $search)
            }
        }
        .applyTabBarMinimizeBehavior()
        .environment(\.horizontalSizeClass, .compact)
    }
}

extension View {
    @ViewBuilder
    func applyTabBarMinimizeBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

#Preview {
    RootView()
}
