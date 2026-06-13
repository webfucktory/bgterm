import AppKit
import ApplicationServices

/// Observes global key-down events via a CGEventTap so bgterm can react to keys
/// macOS reserves (notably F11 / Show Desktop), which the Carbon hotkey API
/// cannot capture. Requires Accessibility permission; the tap is listen-only
/// (it observes, never modifies or swallows events).
final class KeyTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var onKeyDown: ((CGKeyCode) -> Void)?

    /// Whether bgterm currently has Accessibility access.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompt the user for Accessibility access (opens the System Settings pane).
    /// Returns true if already trusted.
    @discardableResult
    static func requestAccess() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Start observing key-down events, or re-enable an existing tap (macOS can
    /// disable taps, and a freshly-trusted process only delivers events after it
    /// has been activated). Safe to call repeatedly. No-op if not trusted.
    @discardableResult
    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if type == .keyDown, let refcon {
                let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async { tap.onKeyDown?(code) }
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
}
