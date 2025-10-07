//
//  ContentView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct RootView: View {
//    @State private var selectedTab: TabIdentifier = .bibleReader
    @State private var appState = DIContainer.shared.resolve(type: AppState.self)
    @State private var search: String = ""
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("BibleReader", systemImage: "book.fill", value: .bibleReader) {
                BibleReaderView()
            }
            Tab("Recordings", systemImage: "waveform", value: .recordings) {
                RecordingsView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(searchText: $search)
            }
        }
        .searchable(text: $search)
        .applyTabBarMinimizeBehavior()
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
