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
