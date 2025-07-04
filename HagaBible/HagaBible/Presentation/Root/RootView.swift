//
//  ContentView.swift
//  HagaBible
//
//  Created by 양시준 on 7/2/25.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("BibleReader", systemImage: "book.fill") {
                BibleReaderView()
            }
            Tab("Recordings", systemImage: "waveform") {
                RecordingsView()
            }
            Tab(role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    RootView()
}
