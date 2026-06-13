import AppKit
import BgtermCore

final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaultsStore()
    private var settings: Settings!
    private var window: DesktopWindow!
    private var surface: TerminalSurface!
    private var reveal: RevealController!
    private var monitor: DesktopVisibilityMonitor!
    private var hotkey: HotkeyManager!
    private let tray = TrayController()
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = Settings(store: defaults)
        guard let screen = NSScreen.main else { return }

        window = DesktopWindow(screen: screen)
        surface = TerminalSurface(frame: screen.frame)
        surface.apply(settings)
        window.contentView = surface.view
        window.moveToDesktopLevel()
        window.orderFront(nil)
        surface.start()

        reveal = RevealController(window: WindowController(window: window))

        monitor = DesktopVisibilityMonitor()
        monitor.onSample = { [weak self] visible in self?.reveal.sampleDesktopVisible(visible) }
        monitor.start()

        hotkey = HotkeyManager()
        hotkey.onTrigger = { [weak self] in self?.reveal.forceFocus() }
        hotkey.register()

        installTray()
        installEscMonitor()

        if !settings.enabledOnLaunch {
            window.orderOut(nil)
            monitor.stop()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func installTray() {
        tray.onToggleEnabled = { [weak self] enabled in
            guard let self else { return }
            if enabled { self.window.orderFront(nil); self.monitor.start() }
            else { self.window.orderOut(nil); self.monitor.stop() }
            var s = self.settings!; s.enabledOnLaunch = enabled; self.settings = s
        }
        tray.onSetOpacity = { [weak self] value in
            guard let self else { return }
            var s = self.settings!; s.opacity = value; self.settings = s
            self.surface.apply(s)
        }
        tray.onRestartShell = { [weak self] in self?.surface.start() }
        tray.onQuit = { NSApp.terminate(nil) }
        tray.install(enabled: settings.enabledOnLaunch)
    }

    private func installEscMonitor() {
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.reveal.escapePressed()
                return nil
            }
            return event
        }
    }

    @objc private func screensChanged() {
        guard let screen = NSScreen.main else { return }
        window.setFrame(screen.frame, display: true)
    }
}

/// UserDefaults-backed KeyValueStore implementation.
final class UserDefaultsStore: KeyValueStore {
    private let d = UserDefaults.standard
    func double(forKey key: String) -> Double? { d.object(forKey: key) == nil ? nil : d.double(forKey: key) }
    func integer(forKey key: String) -> Int? { d.object(forKey: key) == nil ? nil : d.integer(forKey: key) }
    func bool(forKey key: String) -> Bool? { d.object(forKey: key) == nil ? nil : d.bool(forKey: key) }
    func string(forKey key: String) -> String? { d.string(forKey: key) }
    func set(_ value: Any?, forKey key: String) { d.set(value, forKey: key) }
}
