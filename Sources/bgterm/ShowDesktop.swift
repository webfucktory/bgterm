import Foundation

/// Triggers macOS "Show Desktop" (the same action as the F11 / Mission Control
/// gesture) by sending the Dock the notification it listens for. The symbol is
/// resolved at runtime from the already-loaded system frameworks.
enum ShowDesktop {
    private typealias SendNotification = @convention(c) (CFString, Int) -> Void

    /// Toggles the Show Desktop state (reveals the desktop, or restores windows
    /// if already revealed).
    static func toggle() {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "CoreDockSendNotification") else { return }
        let send = unsafeBitCast(sym, to: SendNotification.self)
        send("com.apple.showdesktop.awake" as CFString, 0)
    }
}
