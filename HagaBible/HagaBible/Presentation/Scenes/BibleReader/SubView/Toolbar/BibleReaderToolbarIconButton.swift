//
//  BibleReaderToolbarIconButton.swift
//  HagaBible
//
//  Created by 양시준 on 8/27/25.
//

import SwiftUI

struct BibleReaderToolbarIconButton<LabelContent: View>: View {
    @ViewBuilder let label: LabelContent
    let action: () -> Void
    
    init(action: @escaping () -> Void, @ViewBuilder _ label: () -> LabelContent) where LabelContent: View {
        self.label = label()
        self.action = action
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                label
                    .labelStyle(.iconOnly)
            }
            .toolbarButtonStyle(.circle)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Hello, World!")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BibleReaderToolbarIconButton(action: {}) {
                        Label("Listen", systemImage: "headphones")
                    }
                }
            }
    }
}
