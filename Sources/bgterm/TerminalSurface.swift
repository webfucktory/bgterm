import AppKit
import SwiftTerm
import BgtermCore

/// Terminal view whose opacity is controllable. SwiftTerm leaves NSView.isOpaque
/// at its default (false); declaring it opaque keeps content compositing cleanly
/// at full opacity, while turning it off lets the wallpaper show through when the
/// user dials opacity down.
final class OpaqueTerminalView: LocalProcessTerminalView {
    var forceOpaque = true
    override var isOpaque: Bool { forceOpaque }
}

/// Owns the interactive terminal view and applies appearance settings.
///
/// The terminal is inset inside an opaque black `container` so its text has
/// breathing room from the screen edges; `container` is what the window hosts.
final class TerminalSurface: NSObject, LocalProcessTerminalViewDelegate {
    let container: NSView
    let view: OpaqueTerminalView

    /// Padding between the screen edges and the terminal text.
    private let inset = NSEdgeInsets(top: 28, left: 32, bottom: 28, right: 32)

    init(frame: NSRect) {
        container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        view = OpaqueTerminalView(frame: TerminalSurface.contentFrame(in: frame, inset: inset))
        super.init()
        view.processDelegate = self
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }

    private static func contentFrame(in bounds: NSRect, inset: NSEdgeInsets) -> NSRect {
        NSRect(x: bounds.minX + inset.left,
               y: bounds.minY + inset.bottom,
               width: max(0, bounds.width - inset.left - inset.right),
               height: max(0, bounds.height - inset.top - inset.bottom))
    }

    func start() {
        view.startProcess(
            executable: ShellSession.loginShell(),
            args: [],
            environment: ShellSession.defaultEnvironment(),
            execName: ShellSession.loginArgv0(),   // login shell → profile sets PATH
            currentDirectory: ShellSession.startDirectory()
        )
    }

    func restart() {
        if view.process.running {
            // terminate() sends SIGTERM and calls childStopped(); the processTerminated
            // delegate fires next, which re-spawns via start() on the main queue.
            view.process.terminate()
        } else {
            start()
        }
    }

    func apply(_ settings: Settings) {
        let size = CGFloat(settings.fontSize)
        view.font = NSFont(name: settings.fontName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        view.nativeForegroundColor = .white
        view.nativeBackgroundColor = .black

        let opacity = CGFloat(settings.opacity)
        let opaque = opacity >= 1.0
        view.forceOpaque = opaque
        view.alphaValue = opacity
        container.layer?.backgroundColor = (opaque ? NSColor.black : NSColor.clear).cgColor
    }

    // MARK: LocalProcessTerminalViewDelegate
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // Re-spawn the shell so the wallpaper terminal is never dead.
        DispatchQueue.main.async { [weak self] in self?.start() }
    }
}
