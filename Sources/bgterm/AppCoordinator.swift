import AppKit
import BgtermCore

final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaultsStore()
    private var settings: Settings!
    private var window: DesktopWindow!
    private var tabs: TerminalTabs!
    private var reveal: RevealController!
    private var hotkey: HotkeyManager!
    private let keyTap = KeyTap()
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
        tabs = TerminalTabs(frame: NSRect(origin: .zero, size: window.frame.size),
                            settings: { [weak self] in self?.settings ?? Settings(store: UserDefaultsStore()) })
        window.contentView = tabs.root
        window.initialFirstResponder = tabs.activeView
        applyWindowOpacity(settings)
        window.moveToDesktopLevel()
        window.orderFront(nil)

        reveal = RevealController(window: WindowController(window: window, focusView: { [weak self] in self?.tabs.activeView }))

        hotkey = HotkeyManager()
        hotkey.onTrigger = { [weak self] in self?.toggleViaHotkey() }
        hotkey.register()

        // F11 is reserved by macOS Show Desktop and can't be taken by the hotkey
        // API, so observe it via an event tap (needs Accessibility). macOS still
        // performs the Show Desktop; we only sync focus. Prompt for access here.
        keyTap.onKeyDown = { [weak self] code in
            if code == 0x67 { self?.f11Pressed() }   // F11
        }
        KeyTap.requestAccess()
        keyTap.start()

        installTray()
        installEscMonitor()

        focusEnabled = settings.enabledOnLaunch
        if !settings.enabledOnLaunch {
            window.orderOut(nil)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Re-arm the F11 event tap whenever the app activates (a freshly-trusted
        // process only delivers tap events after its first activation).
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.keyTap.start() }
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
            self.tabs.applyAll(s)
            self.applyWindowOpacity(s)
        }
        tray.onRestartShell = { [weak self] in self?.tabs.restartActive() }
        tray.onQuit = { NSApp.terminate(nil) }
        tray.install(enabled: settings.enabledOnLaunch)
    }

    /// F11: macOS performs Show Desktop itself; we only sync the terminal focus.
    private func f11Pressed() {
        guard focusEnabled else { return }
        if reveal.state == .focused { reveal.escapePressed() } else { reveal.forceFocus() }
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
            guard let self, self.reveal.state == .focused else { return event }

            if event.keyCode == 53 { // Esc
                self.reveal.escapePressed()
                ShowDesktop.toggle()   // restore windows
                return nil
            }

            // Tab shortcuts: ⌘ without ⌥ (⌥⌘T is the global reveal hotkey).
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .command, let chars = event.charactersIgnoringModifiers {
                switch chars {
                case "t":
                    self.tabs.newTab(); self.focusActiveTab(); return nil
                case "w":
                    self.tabs.closeActive(); self.focusActiveTab(); return nil
                case "1", "2", "3", "4", "5", "6", "7", "8", "9":
                    if let n = Int(chars) { self.tabs.select(n - 1); self.focusActiveTab() }
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func focusActiveTab() {
        if let view = tabs.activeView { window.makeFirstResponder(view) }
    }

    /// The window must be non-opaque/clear for the wallpaper to show through when
    /// opacity is below 1; opaque black otherwise.
    private func applyWindowOpacity(_ settings: Settings) {
        let opaque = settings.opacity >= 1.0
        window.isOpaque = opaque
        window.backgroundColor = opaque ? .black : .clear
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
