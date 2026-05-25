//
//  BibleReaderToolbarMenuButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

/// A top-bar menu button that hosts arbitrary menu content, applying the
/// circle toolbar styling on pre-iOS-26 systems.
struct BibleReaderToolbarMenuButton<MenuContent: View, LabelContent: View>: View {
    @ViewBuilder let content: () -> MenuContent
    @ViewBuilder let label: () -> LabelContent

    var body: some View {
        if #available(iOS 26.0, *) {
            Menu(content: content, label: label)
                .menuStyle(.button)
        } else {
            Menu(content: content, label: label)
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
                    BibleReaderToolbarMenuButton {
                        Button(action: {}) {
                            Label("Bookmarks", systemImage: "bookmark")
                        }
                        Button(action: {}) {
                            Label("Font & Themes", systemImage: "textformat.size")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
    }
}
