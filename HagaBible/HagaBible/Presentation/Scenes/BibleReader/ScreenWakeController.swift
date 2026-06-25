//
//  ScreenWakeController.swift
//  HagaBible
//

import SwiftUI
import UIKit

/// Manages the reader's screen-wake behavior: keeping the display awake and,
/// optionally, dimming it after a period of inactivity.
///
/// Two user settings drive it (see `ScreenDisplayPreferences` / `AppState`):
/// - `keepScreenOn`: when `true` the display is prevented from auto-locking
///   (`UIApplication.isIdleTimerDisabled`); when `false` iOS handles dim + lock
///   normally.
/// - `dimAfterSeconds`: while keeping the screen on, dim the brightness to `0`
///   after this many seconds without interaction (`0` = never dim). A tap
///   restores the previous brightness — the device is never locked, so resume
///   is instant (no Face ID / passcode).
///
/// iOS exposes no API for a custom auto-lock duration or a true power-off, so
/// "dim" is implemented by lowering `UIScreen.brightness` ourselves; the
/// reader detects interaction (scrolling, or a tap on the wake overlay) and
/// calls back in to undim and rearm the countdown.
@Observable
@MainActor
final class ScreenWakeController {
    /// `true` while the controller has lowered the screen brightness; drives the
    /// reader's full-screen wake-catcher overlay.
    private(set) var isDimmed = false

    @ObservationIgnored private var dimTask: Task<Void, Never>?
    @ObservationIgnored private var rampTask: Task<Void, Never>?
    @ObservationIgnored private var brightnessBeforeDim: CGFloat?

    /// `true` while at least one finger is on the reading surface. The dim
    /// countdown is suppressed for the whole touch — so the screen never dims
    /// mid-tap or mid-scroll (a slow drag emits no scroll-phase changes to keep
    /// it awake) — and restarts only once the last finger lifts.
    @ObservationIgnored private var isTouchActive = false

    /// Apply the current settings: set the idle-timer state, undim, and (re)arm
    /// the dim countdown. Call on appear and whenever a setting changes.
    func apply(keepScreenOn: Bool, dimAfterSeconds: Int) {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn
        restoreBrightness()
        scheduleDim(keepScreenOn: keepScreenOn, dimAfterSeconds: dimAfterSeconds)
    }

    /// Reset on a discrete interaction (e.g. a scroll-phase change): undim (if
    /// needed) and restart the countdown. While a touch is active `scheduleDim`
    /// no-ops, so this only undims until the finger lifts.
    func userDidInteract(keepScreenOn: Bool, dimAfterSeconds: Int) {
        restoreBrightness()
        scheduleDim(keepScreenOn: keepScreenOn, dimAfterSeconds: dimAfterSeconds)
    }

    /// Report a finger landing on / lifting off the reading surface. While a
    /// touch is active the dim countdown is held off entirely (the screen can't
    /// dim under the user's finger); when the last finger lifts the countdown
    /// restarts so dimming measures genuine inactivity.
    func setTouchActive(_ active: Bool, keepScreenOn: Bool, dimAfterSeconds: Int) {
        isTouchActive = active
        if active {
            dimTask?.cancel()
            dimTask = nil
            restoreBrightness()
        } else {
            scheduleDim(keepScreenOn: keepScreenOn, dimAfterSeconds: dimAfterSeconds)
        }
    }

    /// Restore brightness and pause the countdown without touching the idle
    /// timer — for backgrounding, so other apps aren't left at our dimmed
    /// brightness.
    func suspend() {
        dimTask?.cancel()
        dimTask = nil
        isTouchActive = false
        restoreBrightness()
    }

    /// Release everything when the reader disappears: re-enable the idle timer
    /// and restore brightness.
    func teardown() {
        dimTask?.cancel()
        dimTask = nil
        isTouchActive = false
        restoreBrightness()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func scheduleDim(keepScreenOn: Bool, dimAfterSeconds: Int) {
        dimTask?.cancel()
        dimTask = nil
        // Never arm the countdown under an active touch — it restarts when the
        // finger lifts (`setTouchActive(false:)`).
        guard keepScreenOn, dimAfterSeconds > 0, !isTouchActive else { return }
        // Created from a @MainActor context, so the task inherits MainActor
        // isolation and `dimNow()` runs on the main actor.
        dimTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(dimAfterSeconds))
            guard !Task.isCancelled else { return }
            self?.dimNow()
        }
    }

    /// Duration of the dim ramp (~0.5s, eased). Un-dimming is NOT animated — a tap
    /// to wake restores brightness instantly.
    private static let dimDuration: Double = 0.5

    private func dimNow() {
        guard !isDimmed, let screen = Self.activeScreen else { return }
        brightnessBeforeDim = screen.brightness
        isDimmed = true
        // Ramp the backlight down smoothly rather than snapping to 0.
        rampBrightness(on: screen, to: 0, duration: Self.dimDuration)
    }

    private func restoreBrightness() {
        // Cancel any in-flight dim ramp first, then snap back instantly so waking
        // feels immediate.
        rampTask?.cancel()
        rampTask = nil
        guard isDimmed else { return }
        if let screen = Self.activeScreen, let previous = brightnessBeforeDim {
            screen.brightness = previous
        }
        brightnessBeforeDim = nil
        isDimmed = false
    }

    /// Animate `screen.brightness` to `target` over `duration`. `UIScreen.brightness`
    /// isn't SwiftUI-animatable, so step it manually at ~60fps with an ease-out curve.
    private func rampBrightness(on screen: UIScreen, to target: CGFloat, duration: Double) {
        rampTask?.cancel()
        let start = screen.brightness
        let frameDuration = 1.0 / 60.0
        let steps = max(1, Int((duration / frameDuration).rounded()))
        rampTask = Task { [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 2)   // ease-out quad
                screen.brightness = start + (target - start) * CGFloat(eased)
                try? await Task.sleep(for: .seconds(frameDuration))
            }
            self?.rampTask = nil
        }
    }

    /// The foreground scene's screen, avoiding the deprecated `UIScreen.main`.
    private static var activeScreen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes
        let active = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return (active ?? scenes.first as? UIWindowScene)?.screen
    }
}
