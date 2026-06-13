import AppKit
import BgtermCore

final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaultsStore()
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var settings: Settings!
    private var window: DesktopWindow!
    private var surface: TerminalSurface!
    private var reveal: RevealController!
    private var hotkey: HotkeyManager!
    private let tray = TrayController()
    private var escMonitor: Any?
    private var focusEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = Settings(store: defaults)
        guard let screen = NSScreen.main else {
            tray.install(enabled: false)
            tray.showError("no display found")
            return
        }

        window = DesktopWindow(screen: screen)
        surface = TerminalSurface(frame: NSRect(origin: .zero, size: window.frame.size))
        surface.apply(settings)
        window.contentView = surface.container
        window.initialFirstResponder = surface.view
        window.moveToDesktopLevel()
        window.orderFront(nil)
        surface.start()

        reveal = RevealController(window: WindowController(window: window, focusView: surface.view))

        hotkey = HotkeyManager()
        hotkey.onTrigger = { [weak self] in self?.toggleViaHotkey() }
        hotkey.register()

        installTray()
        installEscMonitor()

        focusEnabled = settings.enabledOnLaunch
        if !settings.enabledOnLaunch {
            window.orderOut(nil)
        }

        // Show Desktop posts no app-level signal, so it can't be auto-detected;
        // clicking the desktop activates Finder, which we can observe to focus.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func installTray() {
        tray.onToggleEnabled = { [weak self] enabled in
            guard let self else { return }
            self.focusEnabled = enabled
            if enabled {
                self.window.orderFront(nil)
            } else {
                self.reveal.escapePressed()
                self.window.orderOut(nil)
            }
            var s = self.settings!; s.enabledOnLaunch = enabled; self.settings = s
        }
        tray.onSetOpacity = { [weak self] value in
            guard let self else { return }
            var s = self.settings!; s.opacity = value; self.settings = s
            self.surface.apply(s)
        }
        tray.onRestartShell = { [weak self] in self?.surface.restart() }
        tray.onQuit = { NSApp.terminate(nil) }
        tray.install(enabled: settings.enabledOnLaunch)
    }

    /// ⌥⌘T: reveal the desktop and focus the terminal, or restore windows and
    /// release focus if already focused.
    private func toggleViaHotkey() {
        guard focusEnabled else { return }
        if reveal.state == .focused {
            reveal.escapePressed()
            ShowDesktop.toggle()   // restore the windows that were moved aside
        } else {
            ShowDesktop.toggle()   // slide windows aside to reveal the desktop
            reveal.forceFocus()
        }
    }

    private func installEscMonitor() {
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53, self.reveal.state == .focused { // Esc while focused
                self.reveal.escapePressed()
                ShowDesktop.toggle()   // restore windows
                return nil
            }
            return event
        }
    }

    /// Drive focus from the active application: focus the terminal when the user
    /// goes to the desktop (Finder becomes active), and release it when any other
    /// app becomes active. Centralising both directions here avoids racing a
    /// window resign-key handler.
    @objc private func appActivated(_ note: Notification) {
        guard focusEnabled,
              let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ownPID
        else { return }
        if app.bundleIdentifier == "com.apple.finder" {
            reveal.forceFocus()
        } else {
            reveal.escapePressed()
        }
    }

    @objc private func screensChanged() {
        guard let screen = NSScreen.main else { return }
        window.setFrame(DesktopWindow.wallpaperRect(for: screen), display: true)
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
