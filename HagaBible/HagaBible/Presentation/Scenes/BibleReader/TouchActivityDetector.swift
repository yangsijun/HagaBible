//
//  TouchActivityDetector.swift
//  HagaBible
//

import SwiftUI
import UIKit

/// Reports every touch that begins inside the view it's attached to, so the reader can
/// treat *any* interaction — a tap, the start of a scroll, a chapter swipe — as activity
/// and keep the dim countdown an idle timer rather than a fixed one.
///
/// Why a UIKit recognizer instead of a SwiftUI gesture: on iOS 18+ SwiftUI gestures (even
/// via `.simultaneousGesture`) hijack the touch from an enclosing `ScrollView`, so scrolling
/// breaks. The fix mirrors `ReadingChapterGrid` — bridge a real `UIGestureRecognizer` that
/// opts into simultaneous recognition. This one goes further: it *fails immediately* on
/// every touch, so it observes interaction without ever delaying, cancelling, or competing
/// with scrolling, taps, or swipes.
struct TouchActivityDetector: UIGestureRecognizerRepresentable {
    /// Called once per touch-down on the attached view.
    let onTouch: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> TouchActivityRecognizer {
        let recognizer = TouchActivityRecognizer()
        recognizer.onTouch = onTouch
        recognizer.delegate = context.coordinator
        // Observe only: never swallow or postpone touches meant for the content.
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TouchActivityRecognizer, context: Context) {
        recognizer.onTouch = onTouch
    }

    func handleUIGestureRecognizerAction(_ recognizer: TouchActivityRecognizer, context: Context) {
        // Never called: the recognizer fails immediately and so never enters a
        // recognized state. Interaction is reported through `onTouch` instead.
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// A gesture recognizer that reports each touch-down and then fails right away. Failing
/// means it bows out of the touch sequence without cancelling it, so the underlying
/// scroll / tap / swipe proceeds untouched; UIKit resets it to `.possible` for the next
/// touch, so every discrete touch-down fires `onTouch` again.
final class TouchActivityRecognizer: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onTouch?()
        state = .failed
    }
}
