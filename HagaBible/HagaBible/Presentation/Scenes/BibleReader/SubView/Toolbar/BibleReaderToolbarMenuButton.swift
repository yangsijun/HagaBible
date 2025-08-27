//
//  BibleReaderToolbarMenuButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

struct BibleReaderToolbarMenuButton<LabelContent: View>: View {
    let menuItems: [MenuItem]
    @ViewBuilder let label: LabelContent
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Menu {
                ForEach(menuItems) { item in
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            } label: {
                label
            }
            .menuStyle(.button)
        } else {
            Menu {
                ForEach(menuItems) { item in
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            } label: {
                label
            }
            .menuStyle(.button)
            .toolbarButtonStyle(.circle)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Hello, World!")
            .toolbar {
                ToolbarItem {
                    BibleReaderToolbarMenuButton(
                        menuItems: [
                            MenuItem(title: "Bookmarks", systemImage: "bookmark", action: {}),
                            MenuItem(title: "Font & Themes", systemImage: "textformat.size", action: {})
                        ]
                    ) {
                        Image(systemName: "ellipsis")
                    }
                } 
            }
    }
}
