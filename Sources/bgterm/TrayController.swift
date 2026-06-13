import AppKit

/// Owns the menu-bar status item and routes menu actions via closures.
final class TrayController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var onToggleEnabled: ((Bool) -> Void)?
    var onSetOpacity: ((Double) -> Void)?
    var onRestartShell: (() -> Void)?
    var onQuit: (() -> Void)?

    private var enabled = true

    func install(enabled: Bool = true) {
        self.enabled = enabled
        statusItem.button?.title = "▮"
        statusItem.button?.toolTip = "bgterm"
        rebuildMenu()
    }

    func showError(_ message: String) {
        statusItem.button?.title = "⚠"
        statusItem.button?.toolTip = "bgterm: \(message)"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: enabled ? "Disable" : "Enable",
                                action: #selector(toggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(opacityItem(0.4))
        menu.addItem(opacityItem(0.7))
        menu.addItem(opacityItem(1.0))
        menu.addItem(.separator())

        let restart = NSMenuItem(title: "Restart shell",
                                 action: #selector(restart), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        let quit = NSMenuItem(title: "Quit bgterm", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func opacityItem(_ value: Double) -> NSMenuItem {
        let item = NSMenuItem(title: "Opacity \(Int(value * 100))%",
                              action: #selector(setOpacity(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = value
        return item
    }

    @objc private func toggle() {
        enabled.toggle()
        onToggleEnabled?(enabled)
        rebuildMenu()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { onSetOpacity?(value) }
    }

    @objc private func restart() { onRestartShell?() }
    @objc private func quit() { onQuit?() }
}
