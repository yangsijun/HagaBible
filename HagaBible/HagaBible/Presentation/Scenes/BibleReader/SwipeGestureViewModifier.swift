//
//  BibleReaderGestureViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct SwipeGestureViewModifier: ViewModifier {
    @State var offset: CGSize = .zero
    
    @State private var dragOffset: CGSize = .zero
    
    var onLeftSwipe: () -> Void
    var onRightSwipe: () -> Void
    
    private func handleSwipe(_ gesture: DragGesture.Value) {
        let swipeThreshold: CGFloat = 50

        if abs(gesture.predictedEndTranslation.width) > swipeThreshold {
            if gesture.predictedEndTranslation.width > 0 {
                onLeftSwipe()
            } else if gesture.predictedEndTranslation.width < 0 {
                onRightSwipe()
            }
        }
        
        self.dragOffset = .zero
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: self.dragOffset.width)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if abs(gesture.translation.width) > abs(gesture.translation.height) {
                            self.dragOffset = gesture.translation
                        } else {
                            withAnimation(.easeInOut) {
                                self.dragOffset = .zero
                            }
                        }
                    }
                    .onEnded { gesture in
                        if abs(gesture.translation.width) > abs(gesture.translation.height) {
                            withAnimation(.easeInOut) {
                                handleSwipe(gesture)
                            }
                        } else {
                            withAnimation(.easeInOut) {
                                self.dragOffset = .zero
                            }
                        }
                    }
            )
    }
}

extension View {
    func swipeGesture(
        onLeftSwipe: @escaping () -> Void,
        onRightSwipe: @escaping () -> Void
    ) -> some View {
        modifier(
            SwipeGestureViewModifier(onLeftSwipe: onLeftSwipe, onRightSwipe: onRightSwipe)
        )
    }
}
