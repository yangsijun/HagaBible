//
//  NavigationTitleButtonModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/6/25.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NavigationTitleButtonModifier<T: StringProtocol, S: StringProtocol>: ViewModifier {
    let title: T
    let subtitle: S
    @State private var scrollOffset: CGFloat = .zero
    private let threshold: CGFloat = -4.0
    @State private var isTitleLarge: Bool = true
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    self.scrollOffset = value
                    self.isTitleLarge = scrollOffset > threshold
                }
                .toolbar {
                    Group {
                        if isTitleLarge {
                            ToolbarItem(placement: .title) {
                                Button(action: {}) {
                                    ViewThatFits(in: .horizontal) {
                                        Text(title)
                                            .font(.largeTitle)
                                        Text(title)
                                            .font(.title)
                                        Text(title)
                                            .font(.title2)
                                        Text(title)
                                            .font(.title3)
                                        Text(title)
                                            .font(.headline)
                                        Text(title)
                                            .font(.caption)
                                    }
                                    .bold()
                                    .lineLimit(1)
                                    .frame(maxWidth: geometry.size.width * 0.4, alignment: .leading)
                                }
                                .padding(.top, 8)
                            }
                            .sharedBackgroundVisibility(.hidden)
                            ToolbarItem(placement: .subtitle) {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ToolbarItem(placement: .principal) {
                                Button(action: {}) {
                                    Text(title)
                                        .font(.headline)
                                        .bold()
                                }
                            }
                            .sharedBackgroundVisibility(.hidden)
                        }
                    }
                }
        }
    }
}

extension View {
    func navigationTitleButton<T: StringProtocol, S: StringProtocol>(
        title: T,
        subtitle: S
    ) -> some View {
            modifier(
                NavigationTitleButtonModifier(
                    title: title,
                    subtitle: subtitle
                )
            )
    }
    
    func navigationTitleButton<T: StringProtocol>(
        title: T
    ) -> some View {
        modifier(
            NavigationTitleButtonModifier(
                title: title,
                subtitle: ""
            )
        )
    }
        
}
