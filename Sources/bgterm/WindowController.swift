import AppKit
import BgtermCore

/// Adapts a DesktopWindow to the WindowControlling protocol used by RevealController.
final class WindowController: WindowControlling {
    private let window: DesktopWindow

    init(window: DesktopWindow) {
        self.window = window
    }

    func enterFocused() {
        window.raiseAndFocus()
    }

    func enterWallpaper() {
        window.moveToDesktopLevel()
    }
}
