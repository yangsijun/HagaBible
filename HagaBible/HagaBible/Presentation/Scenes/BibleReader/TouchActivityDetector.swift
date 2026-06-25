//
//  TouchActivityDetector.swift
//  HagaBible
//

import SwiftUI
import UIKit

/// Reports when a touch begins and ends inside the view it's attached to, so the reader can
/// treat *any* interaction — a tap, the start of a scroll, a chapter swipe — as activity and
/// hold off the dim countdown for the whole touch rather than running a fixed timer that can
/// fire under the user's finger.
///
/// Why a UIKit recognizer instead of a SwiftUI gesture: on iOS 18+ SwiftUI gestures (even
/// via `.simultaneousGesture`) hijack the touch from an enclosing `ScrollView`, so scrolling
/// breaks. The fix mirrors `ReadingChapterGrid` — bridge a real `UIGestureRecognizer` that
/// opts into simultaneous recognition. This one is purely observational: it never transitions
/// out of `.possible` (never recognizes) and keeps `cancelsTouchesInView`/`delaysTouchesBegan`
/// off, so it watches the touch sequence without ever delaying, cancelling, or competing with
/// scrolling, taps, or swipes — which also lets it observe touch *end*, not just touch-down.
struct TouchActivityDetector: UIGestureRecognizerRepresentable {
    /// Called with `true` when the first finger lands and `false` when the last finger lifts.
    let onTouchActiveChanged: (Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> TouchActivityRecognizer {
        let recognizer = TouchActivityRecognizer()
        recognizer.onTouchActiveChanged = onTouchActiveChanged
        recognizer.delegate = context.coordinator
        // Observe only: never swallow or postpone touches meant for the content.
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TouchActivityRecognizer, context: Context) {
        recognizer.onTouchActiveChanged = onTouchActiveChanged
    }

    func handleUIGestureRecognizerAction(_ recognizer: TouchActivityRecognizer, context: Context) {
        // Never called: the recognizer stays in `.possible` and never recognizes. Interaction
        // is reported through `onTouchActiveChanged` instead.
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

/// A purely observational gesture recognizer: it counts active touches and reports when the
/// surface goes from untouched → touched and back, but never leaves `.possible`, so the
/// underlying scroll / tap / swipe proceeds untouched. Tracking begin *and* end (rather than
/// failing on touch-down) is what lets the reader keep the screen lit for an entire touch.
final class TouchActivityRecognizer: UIGestureRecognizer {
    var onTouchActiveChanged: ((Bool) -> Void)?

    private var activeTouchCount = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        // When the app loses the foreground mid-touch, UIKit may never deliver
        // `touchesCancelled`, so this observational recognizer is left holding a
        // phantom touch in `.possible` and is never `reset()`. A recognizer that
        // still "owns" a live touch wedges the window's subsequent *continuous*
        // gestures — the ScrollView pan (scroll) and the chapter-swipe drag stop
        // recognizing — while discrete taps still pass through. Forcing `.failed`
        // on resign drops the held touch and triggers `reset()`, so the foreground
        // returns to a clean gesture state.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppWillResignActive() {
        // `.failed` is a valid transition from `.possible`; it releases any touch
        // this recognizer is tracking and routes through `reset()` below.
        state = .failed
    }

    override func reset() {
        super.reset()
        // Clear the touch tally on every reset (normal touch-end, cancellation, or
        // the forced resign above) so a missed `touchesCancelled` can't strand the
        // count above zero and leave the screen pinned awake / a phantom touch held.
        if activeTouchCount != 0 {
            activeTouchCount = 0
            onTouchActiveChanged?(false)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        let wasInactive = activeTouchCount == 0
        activeTouchCount += touches.count
        if wasInactive {
            onTouchActiveChanged?(true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        activeTouchCount = max(0, activeTouchCount - touches.count)
        if activeTouchCount == 0 {
            onTouchActiveChanged?(false)
        }
    }
}
