//
//  BibleReaderGestureViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct SwipeGestureViewModifier: ViewModifier {
    
    @State private var dragOffset: CGSize = .zero
    @Binding var isDraggingHorizontally: Bool
    
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
            .offset(x: self.dragOffset.width)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        self.dragOffset = gesture.translation
                        self.isDraggingHorizontally = true
                    }
                    .onEnded { gesture in
                        handleSwipe(gesture)
                        
                        self.dragOffset = .zero
                        self.isDraggingHorizontally = false
                    }
            )
    }
}

extension View {
    func swipeGesture(
        isDraggingHorizontally: Binding<Bool>,
        onLeftSwipe: @escaping () -> Void,
        onRightSwipe: @escaping () -> Void
    ) -> some View {
        modifier(
            SwipeGestureViewModifier(isDraggingHorizontally: isDraggingHorizontally, onLeftSwipe: onLeftSwipe, onRightSwipe: onRightSwipe)
        )
    }
}
