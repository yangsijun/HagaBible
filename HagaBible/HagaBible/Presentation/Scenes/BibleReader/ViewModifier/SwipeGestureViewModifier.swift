//
//  BibleReaderGestureViewModifier.swift
//  HagaBible
//
//  Created by 양시준 on 7/7/25.
//

import SwiftUI

struct SwipeGestureViewModifier<NavigationToken: Equatable>: ViewModifier {

    @Environment(\.scenePhase) private var scenePhase

    @State var offset: CGSize = .zero
    @State var isDraggingHorizontally: Bool = false

    /// A value that changes on every chapter/book navigation. Used only to detect that the
    /// reader content has been rebuilt so any stranded in-flight drag state can be cleared.
    var navigationToken: NavigationToken
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
                            let offsetWidth = min(max(gesture.translation.width, -50), 50)
                            offset = CGSize(width: offsetWidth, height: 0)
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
            .onChange(of: scenePhase) { _, phase in
                // If the app is backgrounded mid-drag, iOS cancels the touch but
                // `DragGesture` does not deliver `.onEnded`, leaving
                // `isDraggingHorizontally` stuck `true`. That keeps the wrapped
                // content `.disabled(true)` on return — so scroll and chapter-swipe
                // (both drags) die while taps outside this subtree still work.
                // Clear the in-flight drag state whenever we leave the active phase.
                if phase != .active {
                    isDraggingHorizontally = false
                    offset = .zero
                }
            }
            .onChange(of: navigationToken) { _, _ in
                // Same failure mode as backgrounding, different trigger. A chapter/book
                // change rebuilds the reader content (new verse list) and schedules a
                // programmatic `scrollTo` animation; either can *cancel* an in-flight
                // horizontal `DragGesture` without ever delivering `.onEnded`, stranding
                // `isDraggingHorizontally` at `true`. The content then stays
                // `.disabled(true)` and scrolling freezes until the app is backgrounded.
                // Clearing the drag state on the navigation signal lifts the disable at
                // the exact moment the content reloads, so no stranded lock can survive.
                isDraggingHorizontally = false
                offset = .zero
            }
    }
}

extension View {
    /// - Parameter navigationToken: any value that changes on every chapter/book navigation
    ///   (e.g. the reader's `bibleNavigationUpdateTrigger`). It exists purely so the modifier
    ///   can drop stranded drag state when the content is rebuilt — see the `.onChange` above.
    func swipeGesture<NavigationToken: Equatable>(
        navigationToken: NavigationToken,
        onLeftSwipe: @escaping () -> Void,
        onRightSwipe: @escaping () -> Void
    ) -> some View {
        modifier(
            SwipeGestureViewModifier(
                navigationToken: navigationToken,
                onLeftSwipe: onLeftSwipe,
                onRightSwipe: onRightSwipe
            )
        )
    }
}
