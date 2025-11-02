//
//  ActionBar.swift
//  HagaBible
//
//  Created by 양시준 on 11/2/25.
//

import SwiftUI

struct ActionBar<ActionItems: View>: View {
    @Environment(\.tabBarPlacement) var tabBarPlacement
    @ViewBuilder var actionItems: ActionItems
    
    init(@ViewBuilder _ actionItems: () -> ActionItems) where ActionItems: View {
        self.actionItems = actionItems()
    }
    
    var body: some View {
        HStack {
            Spacer()
            actionItems
        }
        .padding(.horizontal, 30)
        .padding(
            .vertical,
            tabBarPlacement == .bottomBar ? 8 : 30
        )
    }
}

struct ActionBarButtonStyleViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .clipShape(.circle)
    }
}

struct ActionBarButtonLabel: View {
    let systemImage: String

    var body: some View {
        Circle()
            .foregroundStyle(.clear)
            .overlay(
                Image(systemName: systemImage)
            )
            .glassEffect(in: .circle)
    }
}

struct ActionBarButton: View {
    var action: () -> Void
    var systemImage: String
    
    var body: some View {
        Button(action: action) {
            ActionBarButtonLabel(systemImage: systemImage)
        }
        .modifier(ActionBarButtonStyleViewModifier())
    }
}

struct ActionBarShareLink<Item: Transferable>: View {
    var item: Item
    var systemImage: String = "square.and.arrow.up"
    
    var body: some View {
        Group {
            if item is String {
                ShareLink(item: item as! String) {
                    ActionBarButtonLabel(systemImage: systemImage)
                }
            } else if item is URL {
                ShareLink(item: item as! URL) {
                    ActionBarButtonLabel(systemImage: systemImage)
                }
            } else {
                EmptyView()
            }
        }
        .modifier(ActionBarButtonStyleViewModifier())
    }
}
