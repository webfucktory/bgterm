import Foundation

/// Abstraction over the desktop window's focus behaviour so the state machine
/// stays free of AppKit and is unit-testable.
public protocol WindowControlling: AnyObject {
    /// Raise to a focusable level, activate, become key, accept mouse events.
    func enterFocused()
    /// Drop back to desktop level, ignore mouse events, resign key.
    func enterWallpaper()
}

public final class RevealController {
    public enum State: Equatable { case wallpaper, focused }

    public private(set) var state: State = .wallpaper

    private let window: WindowControlling
    private let debounceThreshold: Int
    private var visibleStreak = 0

    public init(window: WindowControlling, debounceThreshold: Int = 2) {
        self.window = window
        self.debounceThreshold = max(1, debounceThreshold)
    }

    /// Fed by the visibility poller. `true` means the desktop appears revealed.
    public func sampleDesktopVisible(_ visible: Bool) {
        if visible {
            visibleStreak += 1
            if visibleStreak >= debounceThreshold {
                transition(to: .focused)
            }
        } else {
            visibleStreak = 0
            transition(to: .wallpaper)
        }
    }

    /// Fallback hotkey: focus regardless of detection.
    public func forceFocus() {
        visibleStreak = debounceThreshold
        transition(to: .focused)
    }

    /// Esc while focused returns to wallpaper.
    public func escapePressed() {
        visibleStreak = 0
        transition(to: .wallpaper)
    }

    private func transition(to next: State) {
        guard next != state else { return }
        state = next
        switch next {
        case .focused: window.enterFocused()
        case .wallpaper: window.enterWallpaper()
        }
    }
}
