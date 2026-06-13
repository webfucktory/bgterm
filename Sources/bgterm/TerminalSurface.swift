import AppKit
import SwiftTerm
import BgtermCore

/// Owns the interactive terminal view and applies appearance settings.
final class TerminalSurface: NSObject, LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView

    init(frame: NSRect) {
        view = LocalProcessTerminalView(frame: frame)
        super.init()
        view.processDelegate = self
        view.autoresizingMask = [.width, .height]
    }

    func start() {
        view.startProcess(
            executable: ShellSession.loginShell(),
            args: [],
            environment: ShellSession.defaultEnvironment()
        )
    }

    func apply(_ settings: Settings) {
        if let font = NSFont(name: settings.fontName, size: CGFloat(settings.fontSize)) {
            view.font = font
        }
        view.nativeForegroundColor = .white
        let bgAlpha = CGFloat(settings.opacity)
        view.nativeBackgroundColor = NSColor.black.withAlphaComponent(bgAlpha)
        view.wantsLayer = true
        view.layer?.isOpaque = settings.opacity >= 1.0
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
