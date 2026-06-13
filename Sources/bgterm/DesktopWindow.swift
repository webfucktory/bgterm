import AppKit

/// Borderless full-screen window that lives at desktop level (behind icons)
/// but can be raised and made key on demand.
final class DesktopWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        setFrame(screen.frame, display: true)
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
        level = .normal
        ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}
