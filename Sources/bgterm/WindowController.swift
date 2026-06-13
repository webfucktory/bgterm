import AppKit
import BgtermCore

/// Adapts a DesktopWindow to the WindowControlling protocol used by RevealController.
final class WindowController: WindowControlling {
    private let window: DesktopWindow
    private let focusView: () -> NSView?

    init(window: DesktopWindow, focusView: @escaping () -> NSView?) {
        self.window = window
        self.focusView = focusView
    }

    func enterFocused() {
        window.raiseAndFocus()
        // Route key input to the active tab's terminal. initialFirstResponder
        // only applies on a window's first key activation, so set it every focus.
        if let view = focusView() {
            window.makeFirstResponder(view)
        }
    }

    func enterWallpaper() {
        window.moveToDesktopLevel()
    }
}
