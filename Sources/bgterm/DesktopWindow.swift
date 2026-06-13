import AppKit

/// Borderless window that lives at desktop level (behind icons) but can be
/// raised and made key on demand. It spans the screen width and runs from the
/// bottom edge up to just below the menu bar, so terminal content is never
/// hidden behind the menu bar or the camera notch.
final class DesktopWindow: NSWindow {
    init(screen: NSScreen) {
        let rect = DesktopWindow.wallpaperRect(for: screen)
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        setFrame(rect, display: true)
    }

    /// Full width, from the bottom of the screen up to just below the menu bar
    /// (and notch). Excludes the menu-bar strip so the terminal's top rows are
    /// visible rather than occluded.
    static func wallpaperRect(for screen: NSScreen) -> NSRect {
        let menuBarInset = screen.frame.maxY - screen.visibleFrame.maxY
        return NSRect(x: screen.frame.minX,
                      y: screen.frame.minY,
                      width: screen.frame.width,
                      height: screen.frame.height - menuBarInset)
    }

    // Borderless windows refuse key/main by default; allow it for focus mode.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func moveToDesktopLevel() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        ignoresMouseEvents = true
        orderBack(nil)
    }

    func raiseAndFocus() {
        // Stay at desktop level (behind icons and windows) but become the key
        // window so it receives keyboard input. Never raised above other windows;
        // never touches macOS Show Desktop.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}
