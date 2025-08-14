//
//  BibleReaderGestureViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct SwipeGestureViewModifier: ViewModifier {
    
    @State var offset: CGSize = .zero
    @State var isDraggingHorizontally: Bool = false
    
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
    }
    
    func body(content: Content) -> some View {
        content
            .disabled(isDraggingHorizontally)
            .offset(x: self.offset.width)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { gesture in
                        if abs(gesture.translation.width) > abs(gesture.translation.height) {
                            offset = gesture.translation
                            isDraggingHorizontally = true
                        } else {
                            withAnimation(.linear(duration: 0.1)) {
                                offset = .zero
                            }
                            isDraggingHorizontally = false
                        }
                    }
                    .onEnded { gesture in
                        if abs(gesture.translation.width) > abs(gesture.translation.height) {
                            handleSwipe(gesture)
                        }
                        withAnimation(.easeInOut) {
                            offset = .zero
                        }
                        isDraggingHorizontally = false
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
            SwipeGestureViewModifier(
                onLeftSwipe: onLeftSwipe,
                onRightSwipe: onRightSwipe
            )
        )
    }
}
