import AppKit
import BgtermCore

/// Adapts a DesktopWindow to the WindowControlling protocol used by RevealController.
final class WindowController: WindowControlling {
    private let window: DesktopWindow
    private let focusView: NSView

    init(window: DesktopWindow, focusView: NSView) {
        self.window = window
        self.focusView = focusView
    }

    func enterFocused() {
        window.raiseAndFocus()
        // Explicitly route key input to the terminal. initialFirstResponder only
        // applies on a window's first key activation, so set it on every focus.
        window.makeFirstResponder(focusView)
    }

    func enterWallpaper() {
        window.moveToDesktopLevel()
    }
}
