import AppKit

/// Polls CGWindowList on a timer and reports desktop visibility.
/// "Visible" = no normal-layer (layer 0) windows from other apps occupy the
/// main screen, which is the state after a Show Desktop gesture.
final class DesktopVisibilityMonitor {
    private var timer: Timer?
    private let interval: TimeInterval
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    var onSample: ((Bool) -> Void)?

    init(interval: TimeInterval = 0.25) {
        self.interval = interval
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.onSample?(self.desktopVisible())
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func desktopVisible() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infos {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let pid = info[kCGWindowOwnerPID as String] as? Int ?? 0
            if layer == 0 && pid != Int(ownPID) {
                return false // a real app window covers the desktop
            }
        }
        return true
    }
}
